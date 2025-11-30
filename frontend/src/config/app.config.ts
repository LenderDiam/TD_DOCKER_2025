/**
 * Application configuration
 */
export interface AppConfig {
  apiBaseUrl: string
  apiTimeout: number
  env: 'development' | 'production' | 'test'
}

/**
 * Get application configuration from environment variables
 */
export const config: AppConfig = {
  // Use relative path '/api' - Nginx reverse proxy handles routing to backend
  apiBaseUrl: import.meta.env.VITE_API_URL || '/api',
  apiTimeout: 10000, // 10 seconds
  env: (import.meta.env.MODE as AppConfig['env']) || 'development'
}
