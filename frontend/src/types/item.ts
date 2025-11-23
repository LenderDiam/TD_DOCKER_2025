/**
 * Item model
 * Represents an item from the API
 */
export interface Item {
  id: number
  title: string
  body: string
  createdAt: string
}

/**
 * API Item (camelCase from backend)
 */
export interface ApiItem {
  id: number
  title: string
  body: string
  createdAt: string
}

/**
 * API Response wrapper
 */
export interface ApiResponse<T> {
  data: T
  error?: string
}

/**
 * Loading state
 */
export interface LoadingState {
  isLoading: boolean
  error: string | null
}
