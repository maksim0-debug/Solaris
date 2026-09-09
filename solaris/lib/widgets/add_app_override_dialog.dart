import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glowing_app_icon.dart';

/// Modal dialog for selecting an active application or adding a custom executable override rule.
class AddAppOverrideDialog extends ConsumerStatefulWidget {
  final List<AppOverrideRule> existingRules;

  const AddAppOverrideDialog({super.key, required this.existingRules});

  static Future<void> show(
    BuildContext context, {
    required List<AppOverrideRule> existingRules,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AddAppOverrideDialog(existingRules: existingRules),
    );
  }

  @override
  ConsumerState<AddAppOverrideDialog> createState() =>
      _AddAppOverrideDialogState();
}

class _AddAppOverrideDialogState extends ConsumerState<AddAppOverrideDialog>
    with SingleTickerProviderStateMixin {
  static const _namesChannel = MethodChannel('com.solaris.monitor/names');

  final TextEditingController _manualExeController = TextEditingController();
  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _selectedNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();

  late AnimationController _refreshAnimController;

  List<Map<String, String>> _runningProcesses = [];
  bool _isLoadingProcesses = true;
  bool _isSaving = false;
  String? _selectedProcessExe;
  int _selectedTab = 0; // 0 = Running apps, 1 = Custom app

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _manualExeController.addListener(_onInputChanged);
    _searchFocusNode.addListener(_onInputChanged);
    _fetchProcesses();
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _manualExeController.removeListener(_onInputChanged);
    _searchFocusNode.removeListener(_onInputChanged);
    _searchFocusNode.dispose();
    _manualExeController.dispose();
    _manualNameController.dispose();
    _selectedNameController.dispose();
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
  }

  Future<void> _fetchProcesses() async {
    if (mounted && !_isLoadingProcesses) {
      setState(() {
        _isLoadingProcesses = true;
      });
    }
    _refreshAnimController.repeat();

    try {
      final List<dynamic>? rawList = await _namesChannel
          .invokeMethod<List<dynamic>>('getRunningProcesses');
      if (rawList != null) {
        final parsed = rawList
            .map((item) {
              final map = Map<Object?, Object?>.from(item as Map);
              return {
                'exe': (map['exe'] ?? '').toString(),
                'title': (map['title'] ?? '').toString(),
              };
            })
            .where((m) => m['exe']!.isNotEmpty)
            .toList();

        // Sort alphabetically by exe
        parsed.sort(
          (a, b) => a['exe']!.toLowerCase().compareTo(b['exe']!.toLowerCase()),
        );

        if (mounted) {
          setState(() {
            _runningProcesses = parsed;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        _refreshAnimController.stop();
        _refreshAnimController.reset();
        setState(() {
          _isLoadingProcesses = false;
        });
      }
    }
  }

  bool get _canSave {
    if (_selectedTab == 0) {
      return _selectedProcessExe != null && _selectedProcessExe!.isNotEmpty;
    }
    return _manualExeController.text.trim().isNotEmpty;
  }

  void _selectProcess(String exe, String title) {
    setState(() {
      _selectedProcessExe = exe;
      _selectedNameController.text = title.isNotEmpty
          ? title.split(' - ').first.trim()
          : exe.replaceAll('.exe', '');
    });
  }

  void _saveRule() {
    if (_isSaving) return;

    final l10n = AppLocalizations.of(context)!;
    var exe = _selectedTab == 0
        ? (_selectedProcessExe ?? '').trim().toLowerCase()
        : _manualExeController.text.trim().toLowerCase();
    var name = _selectedTab == 0
        ? _selectedNameController.text.trim()
        : _manualNameController.text.trim();

    // 1. Strip quotes (e.g. from Windows "Copy as path")
    exe = exe.replaceAll('"', '').replaceAll("'", '').trim();
    name = name.replaceAll('"', '').replaceAll("'", '').trim();

    // 2. Extract filename if user accidentally entered or pasted a full path
    final lastSlash = exe.lastIndexOf(RegExp(r'[/\\]'));
    if (lastSlash != -1) {
      exe = exe.substring(lastSlash + 1);
    }

    if (exe.isEmpty) return;
    _isSaving = true;

    if (!exe.endsWith('.exe')) {
      exe = '$exe.exe';
    }
    if (name.isEmpty) {
      name = exe.replaceAll('.exe', '');
    }

    // Check if the rule exists in built-in rules (isBuiltIn == true) -> Automatic Promotion UX Flow
    final builtInMatch = widget.existingRules.firstWhere(
      (AppOverrideRule r) => r.isBuiltIn && r.exeName.toLowerCase() == exe,
      orElse: () => const AppOverrideRule(exeName: '', appDisplayName: ''),
    );

    if (builtInMatch.exeName.isNotEmpty) {
      // Automatic Promotion
      final messenger = ScaffoldMessenger.of(context);
      ref.read(settingsProvider.notifier).promoteBuiltInToUser(exe);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.appPromotedToast(builtInMatch.appDisplayName)),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      return;
    }

    // Check if user rule already exists -> preserve customized parameters without accidental reset
    final existingUserRule = widget.existingRules.firstWhere(
      (AppOverrideRule r) => !r.isBuiltIn && r.exeName.toLowerCase() == exe,
      orElse: () => const AppOverrideRule(exeName: '', appDisplayName: ''),
    );

    final newRule = existingUserRule.exeName.isNotEmpty
        ? existingUserRule.copyWith(
            appDisplayName: name.isNotEmpty
                ? name
                : existingUserRule.appDisplayName,
            isEnabled: true,
          )
        : AppOverrideRule(
            exeName: exe,
            appDisplayName: name,
            isBuiltIn: false,
            isEnabled: true,
            brightnessMode: AppOverrideMode.global,
            temperatureMode: AppOverrideMode.global,
          );

    ref.read(settingsProvider.notifier).addAppOverride(newRule);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _searchController.text.trim().toLowerCase();

    final filteredProcesses = _runningProcesses.where((p) {
      if (query.isEmpty) return true;
      return p['exe']!.toLowerCase().contains(query) ||
          p['title']!.toLowerCase().contains(query);
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 670),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF131D33), Color(0xFF0C1220)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 36,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(l10n),

              // Segmented Tabs
              _buildTabs(l10n),

              // Tab Body Content
              Flexible(
                child: _selectedTab == 0
                    ? _buildRunningAppsTab(l10n, filteredProcesses)
                    : _buildManualEntryTab(l10n),
              ),

              // Actions Footer
              _buildFooter(l10n, filteredProcesses.length),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              LucideIcons.appWindow,
              color: Color(0xFF818CF8),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.selectAppTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.selectAppSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white54, size: 18),
            splashRadius: 20,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n) {
    final countLabel = _runningProcesses.isNotEmpty
        ? ' (${_runningProcesses.length})'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              icon: LucideIcons.cpu,
              label: '${l10n.runningApps}$countLabel',
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              icon: LucideIcons.filePlus2,
              label: l10n.manualAppEntry,
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningAppsTab(
    AppLocalizations l10n,
    List<Map<String, String>> processes,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Refresh Toolbar
          Builder(
            builder: (context) {
              final isFocused = _searchFocusNode.hasFocus;
              return Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isFocused
                            ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFF6366F1).withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isFocused
                                ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                : Colors.transparent,
                            blurRadius: isFocused ? 10 : 0,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: l10n.searchAppPlaceholder,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              LucideIcons.search,
                              color: isFocused
                                  ? const Color(0xFF818CF8)
                                  : Colors.white.withValues(alpha: 0.45),
                              size: 16,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 42,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? Tooltip(
                                  message: l10n.clearSearch,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                          child: const Icon(
                                            LucideIcons.x,
                                            size: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 42,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ProcessRefreshButton(
                    isLoading: _isLoadingProcesses,
                    animation: _refreshAnimController,
                    onTap: _fetchProcesses,
                    tooltip: l10n.refreshProcesses,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Processes List Box (Expanded to 320px for 7-8 visible items)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoadingProcesses
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                        strokeWidth: 2.5,
                      ),
                    )
                  : processes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.searchX,
                            size: 36,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noRunningApps,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RawScrollbar(
                      controller: _listScrollController,
                      thumbColor: Colors.white.withValues(alpha: 0.18),
                      radius: const Radius.circular(8),
                      thickness: 4,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _listScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        itemCount: processes.length,
                        itemBuilder: (context, index) {
                          final item = processes[index];
                          final exe = item['exe']!;
                          final title = item['title']!;
                          final isSelected = _selectedProcessExe == exe;

                          return _ProcessTile(
                            key: ValueKey(exe),
                            exe: exe,
                            title: title,
                            isSelected: isSelected,
                            tooltip: l10n.processDoubleTapHint,
                            onTap: () => _selectProcess(exe, title),
                            onDoubleTap: () {
                              _selectProcess(exe, title);
                              _saveRule();
                            },
                          );
                        },
                      ),
                    ),
            ),
          ),

          // Anchored Selected Process Bar
          const SizedBox(height: 10),
          _selectedProcessExe != null
              ? Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GlowingAppIcon(
                        key: ValueKey(_selectedProcessExe!),
                        name: _selectedProcessExe!,
                        size: 34,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.selectedProcessLabel.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedProcessExe!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 38),
                          child: TextField(
                            controller: _selectedNameController,
                            onSubmitted: (_) => _canSave ? _saveRule() : null,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: l10n.customDisplayName,
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12,
                              ),
                              prefixIcon: Icon(
                                LucideIcons.pencil,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.3),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6366F1),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.mousePointerClick,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.selectAppHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildManualEntryTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 18,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.manualAppEntryHint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Exe Name Field
          Text(
            l10n.customExeName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _manualExeController,
            onSubmitted: (_) => _canSave ? _saveRule() : null,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'photoshop.exe',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                LucideIcons.fileCode,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Display Name Field
          Text(
            l10n.customDisplayName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _manualNameController,
            onSubmitted: (_) => _canSave ? _saveRule() : null,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Adobe Photoshop',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                LucideIcons.tag,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          if (_selectedTab == 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.cpu,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.processesCount(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _canSave ? _saveRule : null,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(
              l10n.addApp,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF6366F1,
              ).withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: _canSave ? 4 : 0,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF818CF8).withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? const Color(0xFFA5B4FC) : Colors.white54,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessTile extends StatefulWidget {
  final String exe;
  final String title;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _ProcessTile({
    super.key,
    required this.exe,
    required this.title,
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  State<_ProcessTile> createState() => _ProcessTileState();
}

class _ProcessTileState extends State<_ProcessTile> {
  bool _isHovered = false;
  bool _isFocused = false;
  int _lastTapTime = 0;

  void _handleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.onTap(); // Instant 0ms response!
    if (now - _lastTapTime < 320) {
      _lastTapTime =
          0; // Reset to avoid double/triple triggers popping parent routes
      widget.onDoubleTap();
    } else {
      _lastTapTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || _isHovered || _isFocused;
    return Semantics(
      selected: widget.isSelected,
      button: true,
      label: widget.title.isNotEmpty
          ? '${widget.title}, ${widget.exe}'
          : widget.exe,
      hint: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onFocusChange: (f) => setState(() => _isFocused = f),
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                      : (isHighlighted
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFF818CF8).withValues(alpha: 0.5)
                        : (_isFocused
                              ? const Color(0xFF818CF8).withValues(alpha: 0.65)
                              : (_isHovered
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.transparent)),
                    width: _isFocused ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    GlowingAppIcon(
                      key: ValueKey(widget.exe),
                      name: widget.exe,
                      fallbackLetter: widget.title.isNotEmpty
                          ? widget.title
                          : widget.exe,
                      size: 28,
                      borderRadius: 7,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.exe,
                            style: TextStyle(
                              color: widget.isSelected
                                  ? Colors.white
                                  : const Color(0xFFF1F5F9),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (widget.title.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isSelected)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF6366F1),
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: 11,
                          color: Colors.white,
                        ),
                      )
                    else if (_isHovered)
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessRefreshButton extends StatefulWidget {
  final bool isLoading;
  final Animation<double> animation;
  final VoidCallback onTap;
  final String tooltip;

  const _ProcessRefreshButton({
    required this.isLoading,
    required this.animation,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_ProcessRefreshButton> createState() => _ProcessRefreshButtonState();
}

class _ProcessRefreshButtonState extends State<_ProcessRefreshButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isLoading || _isHovered;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.isLoading ? null : widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF818CF8).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: RotationTransition(
                  turns: widget.animation,
                  child: Icon(
                    LucideIcons.rotateCw,
                    color: isActive ? const Color(0xFFA5B4FC) : Colors.white60,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
