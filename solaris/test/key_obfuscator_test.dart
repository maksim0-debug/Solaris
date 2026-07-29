import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:solaris/utils/key_obfuscator.dart';

void main() {
  group('KeyObfuscator (DPAPI & Legacy XOR) Tests', () {
    const rawSecret = 'super-secret-api-key-12345';

    test('XOR Legacy Decryption is backward compatible', () {
      final bytes = utf8.encode('hello');
      final encryptedBytes = bytes.map((b) => b ^ 0x3F).toList();
      final legacyObfuscated = 'obf:${base64Url.encode(encryptedBytes)}';

      final decrypted = KeyObfuscator.decrypt(legacyObfuscated);
      expect(decrypted, equals('hello'));
    });

    test(
      'XOR Legacy Decryption throws DpapiInvalidDataException on corrupted base64',
      () {
        expect(
          () => KeyObfuscator.decrypt('obf:invalid-base-64-%%!!'),
          throwsA(isA<DpapiInvalidDataException>()),
        );
      },
    );

    if (Platform.isWindows) {
      test('Windows DPAPI Encrypt & Decrypt roundtrip works', () {
        final encrypted = KeyObfuscator.encrypt(rawSecret);
        expect(encrypted.startsWith('dpapi:'), isTrue);

        final decrypted = KeyObfuscator.decrypt(encrypted);
        expect(decrypted, equals(rawSecret));
      });

      test(
        'Windows DPAPI Decrypt throws DpapiInvalidDataException on corrupted DPAPI data',
        () {
          expect(
            () => KeyObfuscator.decrypt(
              'dpapi:U29tZSBpbnZhbGlkIGJhc2U2NCBkYXRh',
            ), // valid base64 but invalid DPAPI blob
            throwsA(isA<DpapiInvalidDataException>()),
          );
        },
      );

      test(
        'Stealer attack simulation (CryptUnprotectData without proper entropy fails)',
        () {
          final encrypted = KeyObfuscator.encrypt(rawSecret);
          expect(encrypted.startsWith('dpapi:'), isTrue);

          final rawBase64 = encrypted.substring('dpapi:'.length);
          final encryptedBytes = base64Url.decode(rawBase64);

          final _crypt32 = DynamicLibrary.open('crypt32.dll');
          final _kernel32 = DynamicLibrary.open('kernel32.dll');

          final cryptUnprotectData = _crypt32
              .lookupFunction<
                Int32 Function(
                  Pointer<DATA_BLOB> pDataIn,
                  Pointer<Pointer<Utf16>> ppszDataDescr,
                  Pointer<DATA_BLOB> pOptionalEntropy,
                  Pointer<Void> pvReserved,
                  Pointer<Void> pPromptStruct,
                  Uint32 dwFlags,
                  Pointer<DATA_BLOB> pDataOut,
                ),
                int Function(
                  Pointer<DATA_BLOB> pDataIn,
                  Pointer<Pointer<Utf16>> ppszDataDescr,
                  Pointer<DATA_BLOB> pOptionalEntropy,
                  Pointer<Void> pvReserved,
                  Pointer<Void> pPromptStruct,
                  int dwFlags,
                  Pointer<DATA_BLOB> pDataOut,
                )
              >('CryptUnprotectData');

          final localFree = _kernel32
              .lookupFunction<
                Pointer<Void> Function(IntPtr hMem),
                Pointer<Void> Function(int hMem)
              >('LocalFree');

          final inputPointer = calloc<Uint8>(encryptedBytes.length);
          inputPointer
              .asTypedList(encryptedBytes.length)
              .setAll(0, encryptedBytes);

          final dataIn = calloc<DATA_BLOB>();
          dataIn.ref.cbData = encryptedBytes.length;
          dataIn.ref.pbData = inputPointer;

          final dataOut = calloc<DATA_BLOB>();

          try {
            final result = cryptUnprotectData(
              dataIn,
              nullptr,
              nullptr, // NO entropy - simulated malicious stealer utility!
              nullptr,
              nullptr,
              1, // CRYPTPROTECT_UI_FORBIDDEN
              dataOut,
            );

            expect(
              result,
              equals(0),
            ); // Should fail because we encrypted with custom entropy

            if (result != 0) {
              localFree(dataOut.ref.pbData.address);
            }
          } finally {
            calloc.free(inputPointer);
            calloc.free(dataIn);
            calloc.free(dataOut);
          }
        },
      );
    } else {
      test(
        'Non-Windows platforms fallback to XOR encryption with obf: prefix',
        () {
          final encrypted = KeyObfuscator.encrypt(rawSecret);
          expect(encrypted.startsWith('obf:'), isTrue);

          final decrypted = KeyObfuscator.decrypt(encrypted);
          expect(decrypted, equals(rawSecret));
        },
      );

      test(
        'Non-Windows platforms throw DpapiGenericException when trying to decrypt dpapi: prefixed data',
        () {
          expect(
            () => KeyObfuscator.decrypt('dpapi:c29tZSBkYXRh'),
            throwsA(isA<DpapiGenericException>()),
          );
        },
      );
    }
  });
}
