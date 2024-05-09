import json
import requests

def read_configuration(config_path="./config.json"):
    try:
        with open(config_path, "r") as file:
            config = json.load(file)
            print("Config loaded.")
            return config
    except FileNotFoundError:
        print("Failed to read configuration file. Have you created config.json from the template config_template.json?")
        return None

def build_api_url(title, year, base_url, type_param):
    api_url = f"{base_url}?t={title}&type={type_param}"
    if year:
        api_url += f"&y={year}"
    return api_url

def get_data(title, year, base_url, api_key, type_param):
    api_url = build_api_url(title, year, base_url, type_param)
    try:
        response = requests.get(api_url)
        response.raise_for_status()  # Raise an exception for HTTP errors
        data = response.json()
        print("Response Body:", data)
        return data
    except requests.exceptions.RequestException as e:
        print("Failed to make HTTP request:", e)
        return None

def get_tmdb_data_with_api_key(movie_id, api_key, base_url):
    api_url = f"{base_url}/{movie_id}?api_key={api_key}"
    try:
        response = requests.get(api_url)
        response.raise_for_status()  # Raise an exception for HTTP errors
        data = response.json()
        return data
    except requests.exceptions.RequestException as e:
        print("Failed to fetch data from TMDb with API key:", e)
        return None

def get_tmdb_data_with_bearer_token(movie_id, bearer_token, base_url):
    headers = {"Authorization": f"Bearer {bearer_token}"}
    try:
        response = requests.get(base_url, headers=headers)
        response.raise_for_status()  # Raise an exception for HTTP errors
        data = response.json()
        return data
    except requests.exceptions.RequestException as e:
        print("Failed to fetch data from TMDb with Bearer token:", e)
        return None

def main():
    # Load configuration
    config = read_configuration()
    if not config:
        print("Failed to load config")
        return

    # Get data from OMDB
    omdb_data = get_data("Civil War", "2024", config["Endpoints"]["OmdbEndpoint"], config["Apis"]["OmdbApiKey"], "movie")
    if not omdb_data:
        print("Failed to get data from OMDB API")
        return

    # Get data from TMDb using API key
    tmdb_data_with_api_key = get_tmdb_data_with_api_key("11", config["Apis"]["TmdbApiKey"], config["Endpoints"]["TmdbEndpoint"])
    if not tmdb_data_with_api_key:
        print("Failed to get data from TMDb API with API key")
        return

    # Get data from TMDb using Bearer token
    tmdb_data_with_bearer_token = get_tmdb_data_with_bearer_token("11", config["Apis"]["TmdbBearerToken"], config["Endpoints"]["TmdbEndpoint"])
    if not tmdb_data_with_bearer_token:
        print("Failed to get data from TMDb API with Bearer token")
        return

    # Print some information from the data
    print("OMDB Data:", omdb_data)
    print("TMDb Data with API Key:", tmdb_data_with_api_key)
    print("TMDb Data with Bearer Token:", tmdb_data_with_bearer_token)

if __name__ == "__main__":
    main()
