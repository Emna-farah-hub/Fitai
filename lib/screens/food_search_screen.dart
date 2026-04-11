import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/food_item.dart';
import '../services/food_search_service.dart';
import '../services/meal_journal_service.dart';
import 'food_detail_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealType;

  const FoodSearchScreen({super.key, required this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchService = FoodSearchService();
  final _mealService = MealJournalService();
  Timer? _debounce;
  late TabController _tabController;

  List<FoodItem> _results = [];
  List<FoodItem> _recentItems = [];
  bool _isLoading = true;
  bool _isLoadingRecent = true;
  bool _hasSearched = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final all = await _searchService.getAll();
    if (mounted) {
      setState(() {
        _results = all;
        _isLoading = false;
        _hasSearched = false;
      });
    }
  }

  Future<void> _loadRecent() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final meals = await _mealService.getRecentMeals(uid);
      if (mounted) {
        setState(() {
          _recentItems = meals.map((entry) {
            final factor = entry.quantity > 0 ? entry.quantity / 100 : 1.0;
            return FoodItem(
              id: entry.id,
              name: entry.foodName,
              caloriesPer100g:
                  factor > 0 ? entry.calories / factor : entry.calories,
              protein: factor > 0 ? entry.protein / factor : entry.protein,
              carbs: factor > 0 ? entry.carbs / factor : entry.carbs,
              fats: factor > 0 ? entry.fats / factor : entry.fats,
              glycemicIndex: entry.glycemicIndex,
              isTunisian: false,
              source: 'recent',
              category: 'recent',
            );
          }).toList();
          _isLoadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _loadAll();
      setState(() => _query = '');
      return;
    }
    setState(() {
      _query = query;
      _isLoading = true;
      _hasSearched = true;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _searchService.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _navigateToDetail(FoodItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          foodItem: item,
          mealType: widget.mealType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Food',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.black, fontSize: 15),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search foods...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade500, fontSize: 15),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade500),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4CAF50),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF4CAF50),
            tabs: const [
              Tab(text: 'SEARCH'),
              Tab(text: 'RECENT'),
            ],
          ),

          // Tab body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchBody(),
                _buildRecentBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEARCH TAB ───────────────────────────────────────────

  Widget _buildSearchBody() {
    if (_isLoading) return _buildShimmer();
    if (_hasSearched && _results.isEmpty) return _buildNoResults();
    return _buildResultsList();
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No results for '$_query'",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search term',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (!_hasSearched) {
      // Browse all mode
      return ListView.builder(
        itemCount: _results.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _sectionHeader('ALL FOODS');
          return _foodTile(_results[index - 1]);
        },
      );
    }

    // Search results mode — split into Tunisian, Local, and API
    final tunisian = _results.where((f) => f.isTunisian).toList();
    final local = _results
        .where((f) => !f.isTunisian && f.source != 'openfoodfacts')
        .toList();
    final api =
        _results.where((f) => f.source == 'openfoodfacts').toList();

    final items = <Widget>[
      _sectionHeader("RESULTS FOR '${_query.toUpperCase()}'"),
    ];

    if (tunisian.isNotEmpty) {
      items.add(_subHeader('\u{1F1F9}\u{1F1F3} TUNISIAN'));
      for (final food in tunisian) {
        items.add(_foodTile(food));
      }
    }

    if (local.isNotEmpty) {
      items.add(_subHeader('LOCAL'));
      for (final food in local) {
        items.add(_foodTile(food));
      }
    }

    if (api.isNotEmpty) {
      items.add(_subHeader('\u{1F30D} OPENFOODFACTS'));
      for (final food in api) {
        items.add(_foodTile(food));
      }
    }

    return ListView(children: items);
  }

  // ─── RECENT TAB ───────────────────────────────────────────

  Widget _buildRecentBody() {
    if (_isLoadingRecent) return _buildShimmer();

    if (_recentItems.isEmpty) {
      return const Center(
        child: Text(
          'No recent meals yet',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _sectionHeader('RECENTLY ADDED');
        return _foodTile(_recentItems[index - 1]);
      },
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _subHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sourceBadge(FoodItem item) {
    if (item.isTunisian) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Local',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4CAF50),
          ),
        ),
      );
    }

    if (item.source == 'openfoodfacts') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '\u{1F30D} International',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
      );
    }

    if (item.source == 'recent') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '\u{1F550} Recent',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1565C0),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _foodTile(FoodItem item) {
    return InkWell(
      onTap: () => _navigateToDetail(item),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left side — name and subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _sourceBadge(item),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '100g \u00b7 ${item.caloriesPer100g.toInt()} kcal',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right side — + button
                  GestureDetector(
                    onTap: () => _navigateToDetail(item),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }
}
