import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_flow(phone):
    # 1. Request OTP
    print(f"Requesting OTP for {phone}...")
    resp = requests.post(f"{BASE_URL}/auth/request-otp/", json={"phone_number": phone, "country_code": "92"})
    print(resp.status_code, resp.json())
    otp = resp.json().get('otp')
    if not otp:
        print("Failed to get OTP")
        return

    # 2. Verify OTP
    print(f"Verify OTP {otp} for {phone}...")
    resp = requests.post(f"{BASE_URL}/auth/verify-otp/", json={"phone_number": phone, "otp": otp})
    print(resp.status_code, resp.json())
    token = resp.json().get('access')
    if not token:
        print("Failed to get token")
        return

    # 3. List Users
    print("Listing users...")
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(f"{BASE_URL}/auth/list-users/", headers=headers)
    print(resp.status_code)
    if resp.status_code == 200:
        print(f"Found {len(resp.json())} users")
    else:
        print(resp.json())

if __name__ == "__main__":
    test_flow("3435149587")
