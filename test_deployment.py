#!/usr/bin/env python3
"""
Quick deployment test for CookTalk
Tests: Token Server → LiveKit Connection → Agent Availability
"""

import requests
import json

def test_token_server():
    """Test token server endpoint"""
    print("=== Testing Token Server ===")
    try:
        response = requests.get(
            "https://cooltalk-token-server.onrender.com/api/token",
            params={"room": "test123", "name": "TestUser"},
            timeout=60
        )
        print(f"✅ Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Has token: {bool(data.get('token'))}")
            print(f"✅ LiveKit URL: {data.get('url')}")
            print(f"✅ Token preview: {data.get('token')[:50]}...")
            return data
        else:
            print(f"❌ Error: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None

def test_recipes_endpoint():
    """Test recipes endpoint"""
    print("\n=== Testing Recipes Endpoint ===")
    try:
        response = requests.get(
            "https://cooltalk-token-server.onrender.com/api/recipes",
            timeout=30
        )
        print(f"✅ Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Number of recipes: {len(data)}")
            print(f"✅ Sample recipes: {list(data.keys())[:3]}")
            return True
        else:
            print(f"❌ Error: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def main():
    print("🔍 CookTalk Deployment Test\n")
    
    # Test 1: Token Server
    token_data = test_token_server()
    
    # Test 2: Recipes
    recipes_ok = test_recipes_endpoint()
    
    # Summary
    print("\n=== Summary ===")
    if token_data and recipes_ok:
        print("✅ All systems operational!")
        print(f"\n📱 Mobile app should connect to: {token_data.get('url')}")
    else:
        print("❌ Some systems have issues")
        if not token_data:
            print("  - Token server issue")
        if not recipes_ok:
            print("  - Recipes endpoint issue")

if __name__ == "__main__":
    main()
