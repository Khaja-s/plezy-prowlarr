#!/usr/bin/env python3
"""
Prowlarr API Test Script
========================
Interactive terminal tool to test Prowlarr search and grab functionality.

Usage:
    python prowlarr_test.py

Configuration:
    Edit PROWLARR_URL and API_KEY below, or set environment variables:
    - PROWLARR_URL
    - PROWLARR_API_KEY
"""

import os
import sys
import requests
from datetime import datetime

# ============================================================================
# CONFIGURATION - Edit these or use environment variables
# ============================================================================
PROWLARR_URL = os.getenv("PROWLARR_URL", "http://localhost:9696")
API_KEY = os.getenv("PROWLARR_API_KEY", "9210c4d61f1741eb9e35e47eff918bac")

# ============================================================================
# API Client
# ============================================================================

class ProwlarrClient:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "X-Api-Key": api_key,
            "Content-Type": "application/json"
        }
    
    def test_connection(self) -> dict:
        """Test API connection by getting system status."""
        response = requests.get(
            f"{self.base_url}/api/v1/system/status",
            headers=self.headers,
            timeout=10
        )
        response.raise_for_status()
        return response.json()
    
    def get_indexers(self) -> list:
        """Get list of configured indexers."""
        response = requests.get(
            f"{self.base_url}/api/v1/indexer",
            headers=self.headers,
            timeout=10
        )
        response.raise_for_status()
        return response.json()
    
    def get_download_clients(self) -> list:
        """Get list of configured download clients."""
        response = requests.get(
            f"{self.base_url}/api/v1/downloadclient",
            headers=self.headers,
            timeout=10
        )
        response.raise_for_status()
        return response.json()
    
    def search(self, query: str, categories: list = None, limit: int = 100, 
               sort_by: str = "seeders") -> list:
        """
        Search for releases across all indexers.
        
        Args:
            query: Search term
            categories: List of category IDs (2000=Movies, 5000=TV)
            limit: Max results to return
            sort_by: Sort results by 'seeders', 'size', or 'date' (client-side, Prowlarr doesn't support server-side sorting)
        """
        params = {
            "query": query,
            "limit": limit,
            "type": "search"
        }
        if categories:
            params["categories"] = ",".join(map(str, categories))
        
        response = requests.get(
            f"{self.base_url}/api/v1/search",
            headers=self.headers,
            params=params,
            timeout=60  # Searches can take a while
        )
        response.raise_for_status()
        results = response.json()
        
        # Sort client-side (Prowlarr API doesn't support sorting)
        if sort_by == "seeders":
            results.sort(key=lambda x: x.get("seeders") or 0, reverse=True)
        elif sort_by == "size":
            results.sort(key=lambda x: x.get("size") or 0, reverse=True)
        elif sort_by == "date":
            results.sort(key=lambda x: x.get("publishDate") or "", reverse=True)
        
        return results
    
    def grab_release(self, indexer_id: int, guid: str, download_client_id: int = None) -> dict:
        """
        Grab a release and send it to the download client.
        
        Args:
            indexer_id: The indexer ID from search results
            guid: The release GUID from search results
            download_client_id: Optional specific download client to use
        """
        payload = {
            "indexerId": indexer_id,
            "guid": guid
        }
        if download_client_id:
            payload["downloadClientId"] = download_client_id
        
        response = requests.post(
            f"{self.base_url}/api/v1/search",
            headers=self.headers,
            json=payload,
            timeout=30
        )
        response.raise_for_status()
        return response.json()


# ============================================================================
# Utility Functions
# ============================================================================

def format_size(size_bytes: int) -> str:
    """Convert bytes to human-readable format."""
    if size_bytes == 0:
        return "Unknown"
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(size_bytes) < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} PB"


def format_date(date_str: str) -> str:
    """Format ISO date to readable format."""
    try:
        dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d")
    except:
        return "Unknown"


def print_header(text: str):
    """Print a section header."""
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")


def print_release(index: int, release: dict):
    """Print a single release in a readable format."""
    title = release.get("title", "Unknown")
    indexer = release.get("indexer", "Unknown")
    size = format_size(release.get("size", 0))
    seeders = release.get("seeders", "?")
    leechers = release.get("leechers", "?")
    date = format_date(release.get("publishDate", ""))
    
    print(f"  [{index}] {title[:70]}{'...' if len(title) > 70 else ''}")
    print(f"      Indexer: {indexer} | Size: {size} | S:{seeders} L:{leechers} | {date}")
    print()


# ============================================================================
# Interactive Menu
# ============================================================================

def main():
    print_header("Prowlarr API Test Tool")
    
    # Check configuration
    if API_KEY == "YOUR_API_KEY_HERE":
        print("⚠️  API Key not configured!")
        print("   Edit this script and set API_KEY, or set PROWLARR_API_KEY env var")
        print(f"   Current URL: {PROWLARR_URL}")
        print()
        api_key = input("Enter API Key (or press Enter to exit): ").strip()
        if not api_key:
            sys.exit(1)
    else:
        api_key = API_KEY
    
    client = ProwlarrClient(PROWLARR_URL, api_key)
    
    # Test connection
    print(f"Testing connection to {PROWLARR_URL}...")
    try:
        status = client.test_connection()
        print(f"✅ Connected to Prowlarr v{status.get('version', 'unknown')}")
        print(f"   Instance: {status.get('instanceName', 'default')}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)
    
    # Store last search results for grabbing
    last_results = []
    
    # Main menu loop
    while True:
        print_header("Main Menu")
        print("  1. Search for releases")
        print("  2. List configured indexers")
        print("  3. List download clients")
        print("  4. Grab a release from last search")
        print("  5. Exit")
        print()
        
        choice = input("Select option (1-5): ").strip()
        
        if choice == "1":
            # Search
            print_header("Search Releases")
            query = input("Enter search term: ").strip()
            if not query:
                print("Search cancelled.")
                continue
            
            print("\nCategory filter (optional):")
            print("  [1] Movies (2000)")
            print("  [2] TV Shows (5000)")
            print("  [3] Audio (3000)")
            print("  [4] All categories")
            cat_choice = input("Select category (1-4, default=4): ").strip()
            
            categories = None
            if cat_choice == "1":
                categories = [2000]
            elif cat_choice == "2":
                categories = [5000]
            elif cat_choice == "3":
                categories = [3000]
            
            print(f"\n🔍 Searching for '{query}'...")
            try:
                results = client.search(query, categories=categories, limit=15)
                last_results = results
                
                if not results:
                    print("\n❌ No results found.")
                else:
                    print_header(f"Search Results ({len(results)} found) - Sorted by Seeders ↓")
                    for i, release in enumerate(results[:30]):  # Show top 30 to avoid flooding
                        print_release(i, release)
                    if len(results) > 30:
                        print(f"  ... and {len(results) - 30} more results (showing top 30 by seeders)")
                    print("\n💡 Use option 4 to grab a release by its number.")
            except requests.exceptions.RequestException as e:
                print(f"\n❌ Search failed: {e}")
        
        elif choice == "2":
            # List indexers
            print_header("Configured Indexers")
            try:
                indexers = client.get_indexers()
                if not indexers:
                    print("No indexers configured.")
                else:
                    for idx in indexers:
                        status = "✅" if idx.get("enable", False) else "❌"
                        print(f"  {status} [{idx.get('id')}] {idx.get('name')} ({idx.get('protocol', 'unknown')})")
            except requests.exceptions.RequestException as e:
                print(f"❌ Failed to get indexers: {e}")
        
        elif choice == "3":
            # List download clients
            print_header("Download Clients")
            try:
                clients = client.get_download_clients()
                if not clients:
                    print("No download clients configured.")
                else:
                    for dc in clients:
                        status = "✅" if dc.get("enable", False) else "❌"
                        print(f"  {status} [{dc.get('id')}] {dc.get('name')} ({dc.get('implementation', 'unknown')})")
            except requests.exceptions.RequestException as e:
                print(f"❌ Failed to get download clients: {e}")
        
        elif choice == "4":
            # Grab release
            if not last_results:
                print("\n⚠️  No search results available. Search first!")
                continue
            
            print_header("Grab Release")
            print(f"Available releases (from last search): 0-{len(last_results)-1}")
            
            try:
                idx = int(input("Enter release number to grab: ").strip())
                if idx < 0 or idx >= len(last_results):
                    print("Invalid selection.")
                    continue
                
                release = last_results[idx]
                print(f"\n📥 Grabbing: {release.get('title', 'Unknown')[:60]}...")
                
                result = client.grab_release(
                    indexer_id=release["indexerId"],
                    guid=release["guid"]
                )
                print(f"\n✅ Success! Release sent to download client.")
                print(f"   Title: {result.get('title', 'Unknown')}")
                
            except ValueError:
                print("Invalid number.")
            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 404:
                    print("\n❌ Release not found in cache. Try searching again.")
                elif e.response.status_code == 409:
                    print("\n❌ Failed to get release from indexer.")
                else:
                    print(f"\n❌ Grab failed: {e}")
            except requests.exceptions.RequestException as e:
                print(f"\n❌ Grab failed: {e}")
        
        elif choice == "5":
            print("\nGoodbye! 👋")
            break
        
        else:
            print("\nInvalid option. Please select 1-5.")


if __name__ == "__main__":
    main()
