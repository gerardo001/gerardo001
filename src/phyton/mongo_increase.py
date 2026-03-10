from pymongo import MongoClient

# Connect to MongoDB
client = MongoClient("mongodb://DESKTOP-IBFKIBA:27017/")
db = client["accountgo"]
users_collection = db["users"]

# Get a record from users collection and increase count by 1
users_collection.update_one(
    {},
    {"$inc": {"count": 1}}
)

print("Count increased by 1")
client.close()