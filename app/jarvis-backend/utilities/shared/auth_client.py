import httpx
from typing import Optional, Dict, Any
from fastapi import HTTPException, status, Request
from fastapi.security import HTTPBearer
from .schemas.user import UserResponse


class ServiceHTTPClient:
    """Base HTTP client for service-to-service communication"""

    def __init__(self, base_url: str, timeout: float = 30.0):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout

    async def get(self, endpoint: str, params: Optional[Dict[str, Any]] = None, headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
        """Make GET request to service"""
        url = f"{self.base_url}{endpoint}"

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(url, params=params, headers=headers)

                if response.status_code == 404:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Resource not found"
                    )
                elif response.status_code == 401:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Unauthorized"
                    )
                elif response.status_code == 403:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Forbidden"
                    )
                elif response.status_code >= 400:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Service error: {response.status_code}"
                    )

                return response.json()

        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="Service timeout"
            )
        except httpx.ConnectError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service unavailable"
            )

    async def post(self, endpoint: str, json_data: Optional[Dict[str, Any]] = None, headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
        """Make POST request to service"""
        url = f"{self.base_url}{endpoint}"

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(url, json=json_data, headers=headers)

                if response.status_code == 404:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Resource not found"
                    )
                elif response.status_code == 401:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Unauthorized"
                    )
                elif response.status_code == 403:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Forbidden"
                    )
                elif response.status_code >= 400:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Service error: {response.status_code}"
                    )

                return response.json()

        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="Service timeout"
            )
        except httpx.ConnectError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service unavailable"
            )

class AuthClient:
    """Client for communicating with the auth service"""

    def __init__(self, auth_service_url: str):
        self.client = ServiceHTTPClient(auth_service_url)
        self.bearer_scheme = HTTPBearer(auto_error=False)

    async def validate_token(self, token: str) -> UserResponse:
        """Validate JWT token and return user information"""
        try:
            response_data = await self.client.get(
                "/auth/validate",
                params={"token": token}
            )
            return UserResponse(**response_data)
        except HTTPException:
            # Re-raise HTTP exceptions from the service client
            raise

    async def get_current_user_from_request(self, request: Request) -> UserResponse:
        """Extract and validate user from request cookies (legacy)"""
        token = request.cookies.get("access_token")

        if not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No authentication token found"
            )

        return await self.validate_token(token)

    async def get_current_user_from_bearer_token(self, request: Request) -> UserResponse:
        """Extract and validate user from Authorization header (OAuth2)"""
        auth_header = request.headers.get("Authorization")

        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No bearer token found",
                headers={"WWW-Authenticate": "Bearer"}
            )

        token = auth_header.split(" ")[1]
        return await self.validate_token(token)

    def extract_bearer_token(self, request: Request) -> Optional[str]:
        """Extract bearer token from Authorization header"""
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            return auth_header.split(" ")[1]
        return None
