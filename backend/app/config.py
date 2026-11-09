from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str = "sqlite:///./dev.db"
    google_client_id: str = ""
    linkedin_client_id: str = ""
    linkedin_client_secret: str = ""
    linkedin_redirect_uri: str = ""
    linkedin_version: str = "202605"
    ai_provider: str = "gemini"
    ai_api_key: str = ""
    ai_model: str = "gemini-2.5-flash"
    openrouter_api_key: str = ""
    openai_api_key: str = ""
    token_encryption_key: str = ""  # Fernet key; use a managed KMS in production
    license_signing_secret: str = ""  # long random secret; required outside development
    admin_emails: str = ""
    master_admin_pin: str = "889900"
    frontend_success_url: str = ""
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
