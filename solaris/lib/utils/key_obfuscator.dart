import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:solaris/env/env.dart';

class DpapiPasswordChangedException implements Exception {
  final String message;
  DpapiPasswordChangedException(this.message);
  @override
  String toString() => "DpapiPasswordChangedException: $message";
}

class DpapiInvalidDataException implements Exception {
  final String message;
  DpapiInvalidDataException(this.message);
  @override
  String toString() => "DpapiInvalidDataException: $message";
}

class DpapiGenericException implements Exception {
  final String message;
  DpapiGenericException(this.message);
  @override
  String toString() => "DpapiGenericException: $message";
}

final class DATA_BLOB extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

abstract class _DpapiBindings {
  static final _crypt32 = Platform.isWindows
      ? DynamicLibrary.open('crypt32.dll')
      : null;
  static final _kernel32 = Platform.isWindows
      ? DynamicLibrary.open('kernel32.dll')
      : null;

  static final cryptProtectData = _crypt32
      ?.lookupFunction<
        Int32 Function(
          Pointer<DATA_BLOB> pDataIn,
          Pointer<Utf16> szDataDescr,
          Pointer<DATA_BLOB> pOptionalEntropy,
          Pointer<Void> pvReserved,
          Pointer<Void> pPromptStruct,
          Uint32 dwFlags,
          Pointer<DATA_BLOB> pDataOut,
        ),
        int Function(
          Pointer<DATA_BLOB> pDataIn,
          Pointer<Utf16> szDataDescr,
          Pointer<DATA_BLOB> pOptionalEntropy,
          Pointer<Void> pvReserved,
          Pointer<Void> pPromptStruct,
          int dwFlags,
          Pointer<DATA_BLOB> pDataOut,
        )
      >('CryptProtectData');

  static final cryptUnprotectData = _crypt32
      ?.lookupFunction<
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

  static final localFree = _kernel32
      ?.lookupFunction<
        Pointer<Void> Function(IntPtr hMem),
        Pointer<Void> Function(int hMem)
      >('LocalFree');
}

class KeyObfuscator {
  static const int _xorKey = 0x3F;
  static const String _oldPrefix = "obf:";
  static const String _dpapiPrefix = "dpapi:";
  static const int _cryptProtectUiForbidden = 0x1;

  static String encrypt(String value) {
    if (value.isEmpty) return "";

    // Fallback for non-Windows platforms (e.g. testing or potential porting)
    if (!Platform.isWindows) {
      final bytes = utf8.encode(value);
      final encryptedBytes = bytes.map((b) => b ^ _xorKey).toList();
      return _oldPrefix + base64Url.encode(encryptedBytes);
    }

    final utf8Bytes = utf8.encode(value);

    Pointer<Uint8> inputPointer = nullptr;
    Pointer<DATA_BLOB> dataIn = nullptr;
    Pointer<DATA_BLOB> dataOut = nullptr;
    Pointer<Uint8> entropyPointer = nullptr;
    Pointer<DATA_BLOB> entropyBlob = nullptr;

    final inputLength = utf8Bytes.length;
    int entropyLength = 0;

    try {
      inputPointer = calloc<Uint8>(inputLength);
      final inputList = inputPointer.asTypedList(inputLength);
      inputList.setAll(0, utf8Bytes);

      dataIn = calloc<DATA_BLOB>();
      dataIn.ref.cbData = inputLength;
      dataIn.ref.pbData = inputPointer;

      dataOut = calloc<DATA_BLOB>();

      // Prepare entropy from env with fallback
      final entropyStr = Env.dpapiEntropy;
      final entropyBytes = utf8.encode(
        entropyStr.isNotEmpty ? entropyStr : 'SolarisDefaultEntropySaltKey321!',
      );
      entropyLength = entropyBytes.length;

      entropyPointer = calloc<Uint8>(entropyLength);
      final entropyList = entropyPointer.asTypedList(entropyLength);
      entropyList.setAll(0, entropyBytes);

      entropyBlob = calloc<DATA_BLOB>();
      entropyBlob.ref.cbData = entropyLength;
      entropyBlob.ref.pbData = entropyPointer;

      final protectFn = _DpapiBindings.cryptProtectData;
      if (protectFn == null) {
        throw DpapiGenericException(
          'CryptProtectData function is not available (crypt32.dll missing or corrupt)',
        );
      }

      final result = protectFn(
        dataIn,
        nullptr,
        entropyBlob,
        nullptr,
        nullptr,
        _cryptProtectUiForbidden,
        dataOut,
      );

      if (result == 0) {
        throw DpapiGenericException(
          'CryptProtectData failed: ${GetLastError()}',
        );
      }

      final encryptedBytes = dataOut.ref.pbData.asTypedList(dataOut.ref.cbData);
      final encryptedList = Uint8List.fromList(encryptedBytes);

      return _dpapiPrefix + base64Url.encode(encryptedList);
    } finally {
      // Clear secrets from memory (Memory Remanence Fix)
      if (inputPointer != nullptr && inputLength > 0) {
        inputPointer.asTypedList(inputLength).fillRange(0, inputLength, 0);
      }
      if (dataOut != nullptr &&
          dataOut.ref.pbData != nullptr &&
          dataOut.ref.cbData > 0) {
        dataOut.ref.pbData
            .asTypedList(dataOut.ref.cbData)
            .fillRange(0, dataOut.ref.cbData, 0);
        // Guaranteed release of memory allocated by Windows DPAPI (FFI memory leaks fix)
        final freeFn = _DpapiBindings.localFree;
        if (freeFn != null) {
          freeFn(dataOut.ref.pbData.address);
        }
      }
      if (entropyPointer != nullptr && entropyLength > 0) {
        entropyPointer
            .asTypedList(entropyLength)
            .fillRange(0, entropyLength, 0);
      }

      // Free FFI structures
      if (inputPointer != nullptr) calloc.free(inputPointer);
      if (dataIn != nullptr) calloc.free(dataIn);
      if (dataOut != nullptr) calloc.free(dataOut);
      if (entropyPointer != nullptr) calloc.free(entropyPointer);
      if (entropyBlob != nullptr) calloc.free(entropyBlob);
    }
  }

  static String decrypt(String value) {
    if (value.isEmpty) return "";

    // Support legacy XOR-obfuscation format for seamless migration
    if (value.startsWith(_oldPrefix)) {
      try {
        final rawBase64 = value.substring(_oldPrefix.length);
        final encryptedBytes = base64Url.decode(rawBase64);
        final decryptedBytes = encryptedBytes.map((b) => b ^ _xorKey).toList();
        return utf8.decode(decryptedBytes);
      } catch (_) {
        throw DpapiInvalidDataException('Failed to decrypt old XOR format');
      }
    }

    if (!value.startsWith(_dpapiPrefix)) {
      return value;
    }

    if (!Platform.isWindows) {
      throw DpapiGenericException('DPAPI is only supported on Windows');
    }

    Pointer<Uint8> inputPointer = nullptr;
    Pointer<DATA_BLOB> dataIn = nullptr;
    Pointer<DATA_BLOB> dataOut = nullptr;
    Pointer<Uint8> entropyPointer = nullptr;
    Pointer<DATA_BLOB> entropyBlob = nullptr;

    int inputLength = 0;
    int entropyLength = 0;

    try {
      final rawBase64 = value.substring(_dpapiPrefix.length);
      final encryptedBytes = base64Url.decode(rawBase64);
      inputLength = encryptedBytes.length;

      inputPointer = calloc<Uint8>(inputLength);
      final inputList = inputPointer.asTypedList(inputLength);
      inputList.setAll(0, encryptedBytes);

      dataIn = calloc<DATA_BLOB>();
      dataIn.ref.cbData = inputLength;
      dataIn.ref.pbData = inputPointer;

      dataOut = calloc<DATA_BLOB>();

      // Prepare entropy from env with fallback
      final entropyStr = Env.dpapiEntropy;
      final entropyBytes = utf8.encode(
        entropyStr.isNotEmpty ? entropyStr : 'SolarisDefaultEntropySaltKey321!',
      );
      entropyLength = entropyBytes.length;

      entropyPointer = calloc<Uint8>(entropyLength);
      final entropyList = entropyPointer.asTypedList(entropyLength);
      entropyList.setAll(0, entropyBytes);

      entropyBlob = calloc<DATA_BLOB>();
      entropyBlob.ref.cbData = entropyLength;
      entropyBlob.ref.pbData = entropyPointer;

      final unprotectFn = _DpapiBindings.cryptUnprotectData;
      if (unprotectFn == null) {
        throw DpapiGenericException(
          'CryptUnprotectData function is not available (crypt32.dll missing or corrupt)',
        );
      }

      final result = unprotectFn(
        dataIn,
        nullptr,
        entropyBlob,
        nullptr,
        nullptr,
        _cryptProtectUiForbidden,
        dataOut,
      );

      if (result == 0) {
        final errorCode = GetLastError();
        final u32Code = errorCode & 0xFFFFFFFF;
        // NTE_BAD_KEYSET = 0x80090016
        // SEC_E_DECRYPT_FAILURE = 0x80090020
        // NTE_BAD_KEY_STATE = 0x8009000B (most common error when credentials change or password is reset)
        // NTE_FAIL = 0x8009000F
        if (u32Code == 0x80090016 ||
            u32Code == 0x80090020 ||
            u32Code == 0x8009000B ||
            u32Code == 0x8009000F) {
          throw DpapiPasswordChangedException(
            'Windows password changed or credentials invalid: 0x${u32Code.toRadixString(16)}',
          );
        }
        throw DpapiInvalidDataException(
          'CryptUnprotectData failed (probably corrupted data or wrong entropy): 0x${u32Code.toRadixString(16)}',
        );
      }

      final decryptedBytes = dataOut.ref.pbData.asTypedList(dataOut.ref.cbData);
      final resultString = utf8.decode(decryptedBytes);

      return resultString;
    } on DpapiPasswordChangedException {
      rethrow;
    } on DpapiInvalidDataException {
      rethrow;
    } on DpapiGenericException {
      rethrow;
    } catch (e) {
      throw DpapiInvalidDataException('Invalid DPAPI base64 data: $e');
    } finally {
      // Clear secrets from memory (Memory Remanence Fix)
      if (inputPointer != nullptr && inputLength > 0) {
        inputPointer.asTypedList(inputLength).fillRange(0, inputLength, 0);
      }
      if (dataOut != nullptr &&
          dataOut.ref.pbData != nullptr &&
          dataOut.ref.cbData > 0) {
        dataOut.ref.pbData
            .asTypedList(dataOut.ref.cbData)
            .fillRange(0, dataOut.ref.cbData, 0);
        // Guaranteed release of memory allocated by Windows DPAPI (FFI memory leaks fix)
        final freeFn = _DpapiBindings.localFree;
        if (freeFn != null) {
          freeFn(dataOut.ref.pbData.address);
        }
      }
      if (entropyPointer != nullptr && entropyLength > 0) {
        entropyPointer
            .asTypedList(entropyLength)
            .fillRange(0, entropyLength, 0);
      }

      // Free FFI structures
      if (inputPointer != nullptr) calloc.free(inputPointer);
      if (dataIn != nullptr) calloc.free(dataIn);
      if (dataOut != nullptr) calloc.free(dataOut);
      if (entropyPointer != nullptr) calloc.free(entropyPointer);
      if (entropyBlob != nullptr) calloc.free(entropyBlob);
    }
  }
}
