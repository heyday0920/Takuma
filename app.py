from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import requests
from collections import Counter
import os
import mysql.connector  # MySQLコネクタをインポート

app = Flask(__name__)
CORS(app)  # CORSを有効化

# 推奨: APIキーは環境変数で管理
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY") or "AIzaSyCsHd6IiiR5znUgVGF6GBIpz1sjzohy_aY"

# MySQLの接続情報
DB_CONFIG = {
    'host': os.getenv("MYSQL_HOST") or "localhost",
    'user': os.getenv("MYSQL_USER") or "root",
    'password': os.getenv("MYSQL_PASSWORD") or "takumakimi0920!!",
    'database': os.getenv("MYSQL_DB") or "restaurant_app_db"
}

# データベース接続関数
def get_db_connection():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        print("データベース接続成功")  # 接続成功メッセージ
        return conn
    except mysql.connector.Error as err:
        print(f"データベース接続エラー: {err}")
        return None

def search_places_nearby(latitude, longitude, keyword="", radius=10000, place_type="restaurant"):
    url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    params = {
        "location": f"{latitude},{longitude}",
        "radius": radius,
        "type": place_type,
        "keyword": keyword,
        "language": "ja",
        "key": GOOGLE_API_KEY
    }
    response = requests.get(url, params=params)
    print(f"NearbySearch APIレスポンス: {response.status_code}: {response.url}")
    return response.json()

@app.route('/place_photo')
def place_photo():
    photo_reference = request.args.get("photo_reference")
    if not photo_reference:
        return "photo_reference required", 400
    url = f"https://maps.googleapis.com/maps/api/place/photo"
    params = {
        "maxwidth": 400,
        "photoreference": photo_reference,
        "key": GOOGLE_API_KEY
    }
    r = requests.get(url, params=params, stream=True)
    return Response(r.content, content_type=r.headers.get('Content-Type'))

def get_place_photo_url(photos):
    if not photos:
        return "https://via.placeholder.com/400x300.png?text=No+Image"
    photo_ref = photos[0].get("photo_reference")
    return f"http://127.0.0.1:5000/place_photo?photo_reference={photo_ref}"

def get_place_details(place_id):
    url = "https://maps.googleapis.com/maps/api/place/details/json"
    params = {
        "place_id": place_id,
        "fields": "formatted_phone_number,reviews",
        "language": "ja",
        "key": GOOGLE_API_KEY
    }
    try:
        response = requests.get(url, params=params, timeout=5)
        print(f"PlaceDetails APIレスポンス: {response.status_code}: {response.url}")
        details = response.json().get("result", {})
        if not details:
            print(f"Details取得失敗: {response.json()}")
        return details
    except Exception as e:
        print(f"PlaceDetails APIエラー: {e}")
        return {}

def build_restaurant_dict(place):
    details = get_place_details(place.get("place_id"))
    return {
        "id": place.get("place_id"),
        "name": place.get("name"),
        "latitude": place["geometry"]["location"]["lat"],
        "longitude": place["geometry"]["location"]["lng"],
        "genre": ",".join(place.get("types", [])),
        "rating": place.get("rating", 0),
        "image_url": get_place_photo_url(place.get("photos", [])),
        "address": place.get("vicinity", ""),
        "phone": details.get("formatted_phone_number", ""),
        "reviews": details.get("reviews", []),
    }

@app.route('/nearby_restaurants', methods=['POST'])
def get_nearby_restaurants():
    try:
        data = request.json
        print("受信データ:", data)
        user_lat = float(data['latitude'])
        user_lon = float(data['longitude'])
        radius = data.get('radius', 10000)
        place_type = data.get('type', 'restaurant')
        keyword = data.get('keyword', '')

        places_data = search_places_nearby(user_lat, user_lon, keyword=keyword, radius=radius, place_type=place_type)
        print("Google APIレスポンス: status =", places_data.get("status"), "results件数 =", len(places_data.get("results", [])))

        # 最大10件取得（API消費を抑えるため）
        restaurants = [build_restaurant_dict(place) for place in places_data.get("results", [])[:10]]
        print("例:", restaurants[0] if restaurants else "なし")
        print("返却データ件数:", len(restaurants))
        return jsonify(restaurants)
    except Exception as e:
        print("エラー:", e)
        return jsonify({"error": str(e)}), 500

@app.route('/recommend_restaurants', methods=['POST'])
def recommend_restaurants():
    conn = None
    try:
        data = request.json
        user_lat = float(data['latitude'])
        user_lon = float(data['longitude'])
        liked_restaurants_data = data.get('liked_restaurants', [])
        noped_restaurants_data = data.get('noped_restaurants', [])

        # DB接続
        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor()

        # Likeされたお店を保存
        user_id = "anonymous_user"  # 実際には適切なユーザーIDを渡してください
        for restaurant in liked_restaurants_data:
            print("LIKEするお店データ:", restaurant)  # 追加: 挿入データを表示
            place_name = restaurant['name']  # 店舗名を取得
            genre_str = restaurant['genre'] if restaurant['genre'] else 'unknown'
            sql = "INSERT INTO user_actions (user_id, place_name, action_type, genre) VALUES (%s, %s, %s, %s)"
            val = (user_id, place_name, 'LIKE', genre_str)
            try:
                cursor.execute(sql, val)
                conn.commit()  # 変更をコミット
            except mysql.connector.Error as err:
                print(f"LIKEデータの挿入エラー: {err}")
                conn.rollback()  # エラー時はロールバック

        # Nopeされたお店を保存
        for restaurant in noped_restaurants_data:
            place_name = restaurant['name']  # 店舗名を取得
            genre_str = restaurant['genre'] if restaurant['genre'] else 'unknown'
            sql = "INSERT INTO user_actions (user_id, place_name, action_type, genre) VALUES (%s, %s, %s, %s)"
            val = (user_id, place_name, 'NOPE', genre_str)
            try:
                cursor.execute(sql, val)
                conn.commit()
            except mysql.connector.Error as err:
                print(f"NOPEデータの挿入エラー: {err}")
                conn.rollback()

        # リコメンドのロジック
        liked_genres_list = []
        for restaurant in liked_restaurants_data:
            genres = [g.strip() for g in restaurant['genre'].split(',') if g.strip()]
            liked_genres_list.extend(genres)

        if liked_genres_list:
            top_genre = Counter(liked_genres_list).most_common(1)[0][0]
            print(f"集計されたLikedジャンル: {liked_genres_list}, トップジャンル: {top_genre}")
        else:
            top_genre = "restaurant"
            print(f"Likedジャンルなし、デフォルト: {top_genre}")

        places_data = search_places_nearby(user_lat, user_lon, keyword=top_genre)
        print(f"リコメンド: keyword={top_genre}, status={places_data.get('status')}")
        restaurants = [build_restaurant_dict(place) for place in places_data.get("results", [])[:10]]
        print("例:", restaurants[0] if restaurants else "なし")

        return jsonify(restaurants)
    except Exception as e:
        print("エラー:", e)
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("データベース接続を閉じました。")

if __name__ == '__main__':
    app.run(debug=True)
