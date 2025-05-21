import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:page_transition/page_transition.dart'; // page_transitionパッケージをインポート

void main() {
  runApp(RestaurantSwipeApp());
}

class RestaurantSwipeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
      theme: ThemeData(
        fontFamily: 'NotoSansJP',
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    final email = _emailController.text;
    final password = _passwordController.text;

    Navigator.of(context).pushReplacement(
      PageTransition(
        type: PageTransitionType.fade,
        child: RestaurantSwipeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ログイン")),
      body: Stack(
        children: <Widget>[
          Opacity(
            opacity: 0.7,
            child: Image.network(
              'https://images.pexels.com/photos/36487/tokyo-japan-asia-night.jpg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "メールアドレス",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "パスワード",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                ElevatedButton(onPressed: _login, child: Text("ログイン")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantSwipeScreen extends StatefulWidget {
  @override
  _RestaurantSwipeScreenState createState() => _RestaurantSwipeScreenState();
}

class _RestaurantSwipeScreenState extends State<RestaurantSwipeScreen> with TickerProviderStateMixin { // MODIFIED: Added TickerProviderStateMixin
  List<Map<String, dynamic>> restaurants = [];
  List<Map<String, dynamic>> likedRestaurants = [];
  List<Map<String, dynamic>> nopedRestaurants = [];
  bool isLoading = true;
  double? currentLat;
  double? currentLon;
  int swipeCount = 0;

  final CardSwiperController _controller = CardSwiperController();
  final ScrollController _reviewsScrollController = ScrollController();

  // Animation Controllers
  late AnimationController _likeButtonAnimationController;
  late Animation<double> _likeButtonAnimation;
  late AnimationController _nopeButtonAnimationController;
  late Animation<double> _nopeButtonAnimation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // LIKE button animation setup
    _likeButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeButtonAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeButtonAnimationController, curve: Curves.easeOut),
    );

    // NOPE button animation setup
    _nopeButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _nopeButtonAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _nopeButtonAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _reviewsScrollController.dispose();
    _likeButtonAnimationController.dispose(); // MODIFIED: Dispose controller
    _nopeButtonAnimationController.dispose(); // MODIFIED: Dispose controller
    super.dispose();
  }

  // Helper function to trigger bounce
  void _triggerBounceAnimation(AnimationController controller) {
    controller.forward().then((_) {
      controller.reverse();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => isLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => isLoading = false);
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentLat = position.latitude;
      currentLon = position.longitude;
      await fetchNearbyRestaurants(currentLat!, currentLon!);
    } catch (e) {
      print("位置情報取得エラー: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchNearbyRestaurants(double latitude, double longitude) async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/nearby_restaurants");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"latitude": latitude, "longitude": longitude}),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          restaurants = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        print("飲食店データの取得失敗: ${response.statusCode}, Body: ${response.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("飲食店データの取得エラー: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final uri = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('電話アプリを開けませんでした。')));
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecommended(
    List<String> likedGenres,
  ) async {
    final url = Uri.parse("http://127.0.0.1:5000/recommend_restaurants");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "latitude": currentLat,
          "longitude": currentLon,
          "liked_restaurants": likedRestaurants, 
          "noped_restaurants": nopedRestaurants, 
        }),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print("リコメンド取得失敗: ${response.statusCode}, Body: ${response.body}");
        return [];
      }
    } catch (e) {
      print("リコメンド取得エラー: $e");
      return [];
    }
  }

  void _tryGoToRecommend(BuildContext context) {
    if (swipeCount >= 5) {
      List<String> likedGenres =
          likedRestaurants
              .map((e) => (e["genre"] as String? ?? "").split(","))
              .expand((e) => e)
              .where((genre) => genre.trim().isNotEmpty)
              .toList();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => RecommendedScreen(
                genres: likedGenres,
                latitude: currentLat!,
                longitude: currentLon!,
                fetchRecommended: fetchRecommended,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (swipeCount >= 5) {
      Future.microtask(() => _tryGoToRecommend(context));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("飲食店スワイプ"),
        backgroundColor: Colors.deepOrange,
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : restaurants.isEmpty
              ? Center(child: Text("お店が見つかりませんでした"))
              : Column(
                children: [
                  Expanded(
                    child: CardSwiper(
                      controller: _controller,
                      cardsCount: restaurants.length,
                      numberOfCardsDisplayed: 1,
                      cardBuilder: (context, index, realIndex, cardsCount) {
                        final restaurant = restaurants[index];
                        final List<dynamic> reviews =
                            restaurant["reviews"] ?? [];

                        return Center(
                          child: Material(
                            elevation: 20,
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white,
                            child: Container(
                              width: 350,
                              padding: EdgeInsets.all(20),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        restaurant["image_url"] ?? "",
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[200],
                                                  height: 180,
                                                  child: Icon(
                                                    Icons.restaurant,
                                                    size: 80,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      restaurant["name"] ?? "",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      restaurant["address"] ?? "",
                                      style: TextStyle(color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 4),
                                    if ((restaurant["phone"] ?? "").isNotEmpty)
                                      GestureDetector(
                                        onTap:
                                            () => _launchPhone(
                                              restaurant["phone"],
                                            ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 18,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              restaurant["phone"],
                                              style: TextStyle(
                                                fontSize: 15,
                                                decoration:
                                                    TextDecoration.underline,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "${restaurant["rating"] ?? "-"}",
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    if (reviews.isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Divider(),
                                          Text(
                                            "口コミ",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(
                                            height: 80,
                                            child: Scrollbar(
                                              thumbVisibility: true,
                                              controller:
                                                  _reviewsScrollController,
                                              child: ListView.builder(
                                                controller:
                                                    _reviewsScrollController,
                                                itemCount: reviews.length,
                                                itemBuilder: (context, idx) {
                                                  final review = reviews[idx];
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 4.0,
                                                        ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if ((review["profile_photo_url"] ??
                                                                "")
                                                            .isNotEmpty)
                                                          CircleAvatar(
                                                            radius: 12,
                                                            backgroundImage:
                                                                NetworkImage(
                                                                  review["profile_photo_url"],
                                                                ),
                                                          ),
                                                        SizedBox(width: 6),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    review["author_name"] ??
                                                                        "",
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Icon(
                                                                    Icons.star,
                                                                    color:
                                                                        Colors
                                                                            .orange,
                                                                    size: 14,
                                                                  ),
                                                                  Text(
                                                                    "${review["rating"] ?? "-"}",
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    review["relative_time_description"] ??
                                                                        "",
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color:
                                                                          Colors
                                                                              .grey,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                review["text"] ??
                                                                    "",
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  color:
                                                                      Colors
                                                                          .black87,
                                                                ),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      onSwipe: (previousIndex, currentIndex, direction) {
                        final restaurant = restaurants[previousIndex];
                        if (direction == CardSwiperDirection.right) {
                          likedRestaurants.add(restaurant);
                          _triggerBounceAnimation(_likeButtonAnimationController); // MODIFIED: Trigger animation
                          print("LIKEしたお店: ${restaurant["name"]}");
                        } else if (direction == CardSwiperDirection.left) {
                          nopedRestaurants.add(restaurant);
                          _triggerBounceAnimation(_nopeButtonAnimationController); // MODIFIED: Trigger animation
                          print("NOPEしたお店: ${restaurant["name"]}");
                        }
                        swipeCount++;
                        setState(() {});
                        return true;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 40,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ScaleTransition( // MODIFIED: Wrapped with ScaleTransition
                          scale: _nopeButtonAnimation,
                          child: ElevatedButton(
                            onPressed: () {
                              _triggerBounceAnimation(_nopeButtonAnimationController); // MODIFIED: Trigger animation
                              _controller.swipe(CardSwiperDirection.left);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade400,
                              minimumSize: Size(120, 50),
                            ),
                            child: Text("NOPE", style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        ScaleTransition( // MODIFIED: Wrapped with ScaleTransition
                          scale: _likeButtonAnimation,
                          child: ElevatedButton(
                            onPressed: () {
                              _triggerBounceAnimation(_likeButtonAnimationController); // MODIFIED: Trigger animation
                              _controller.swipe(CardSwiperDirection.right);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellowAccent.shade700,
                              minimumSize: Size(120, 50),
                            ),
                            child: Text("LIKE", style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

// おすすめ画面
class RecommendedScreen extends StatelessWidget {
  final List<String> genres;
  final double latitude;
  final double longitude;
  final Future<List<Map<String, dynamic>>> Function(List<String>)
  fetchRecommended;

  RecommendedScreen({
    required this.genres,
    required this.latitude,
    required this.longitude,
    required this.fetchRecommended,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchRecommended(genres),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text("あなたへのおすすめ")),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text("あなたへのおすすめ")),
            body: Center(child: Text("おすすめの取得中にエラーが発生しました: ${snapshot.error}")),
          );
        }
        final recommended = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: Text("あなたへのおすすめ")),
          body:
              recommended.isEmpty
                  ? Center(child: Text("条件に合うおすすめ店舗が見つかりませんでした"))
                  : ListView.builder(
                    itemCount: recommended.length,
                    itemBuilder: (context, index) {
                      final shop = recommended[index];
                      return Card(
                        margin: EdgeInsets.all(12),
                        child: ListTile(
                          leading: Image.network(
                            shop["image_url"] ?? "",
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                          title: Text(shop["name"] ?? ""),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("評価: ${shop["rating"] ?? "-"}"),
                              Text(shop["address"] ?? ""),
                              if ((shop["phone"] ?? "").isNotEmpty)
                                Text("電話: ${shop["phone"]}"),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}
