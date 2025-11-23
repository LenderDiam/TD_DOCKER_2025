import { config } from '../config/app.config'
import type { ApiItem } from '../types/item'
import { ApiError } from '../utils/errors'

/**
 * Base API Service
 * Handles HTTP requests with error handling and timeouts
 */
class ApiService {
  private baseUrl: string
  private timeout: number

  constructor() {
    this.baseUrl = config.apiBaseUrl
    this.timeout = config.apiTimeout
  }

  /**
   * Fetch with timeout
   */
  private async fetchWithTimeout(
    url: string,
    options: RequestInit = {}
  ): Promise<Response> {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), this.timeout)

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal
      })
      
      clearTimeout(timeoutId)
      return response
    } catch (error) {
      clearTimeout(timeoutId)
      
      if (error instanceof Error && error.name === 'AbortError') {
        throw new ApiError('Request timeout', 408, error)
      }
      
      throw error
    }
  }

  /**
   * Handle API response
   */
  private async handleResponse<T>(response: Response): Promise<T> {
    if (!response.ok) {
      const errorMessage = `HTTP ${response.status}: ${response.statusText}`
      throw new ApiError(errorMessage, response.status)
    }

    try {
      return await response.json()
    } catch (error) {
      throw new ApiError('Invalid JSON response', response.status, error)
    }
  }

  /**
   * GET request
   */
  async get<T>(endpoint: string): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`
    
    try {
      const response = await this.fetchWithTimeout(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      })
      
      return this.handleResponse<T>(response)
    } catch (error) {
      if (error instanceof ApiError) {
        throw error
      }
      
      throw new ApiError(
        'Failed to fetch data',
        undefined,
        error
      )
    }
  }
}

/**
 * Items API Service
 * Handles all item-related API calls
 */
class ItemsService {
  private api: ApiService

  constructor() {
    this.api = new ApiService()
  }

  /**
   * Get all items
   */
  async getAll(): Promise<ApiItem[]> {
    return this.api.get<ApiItem[]>('/items')
  }

  /**
   * Get item by ID
   */
  async getById(id: number): Promise<ApiItem> {
    return this.api.get<ApiItem>(`/items/${id}`)
  }
}

// Export singleton instance
export const itemsService = new ItemsService()
