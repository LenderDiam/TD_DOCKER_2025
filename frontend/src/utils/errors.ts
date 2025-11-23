/**
 * Custom error class for API errors
 */
export class ApiError extends Error {
  statusCode?: number
  originalError?: unknown

  constructor(
    message: string,
    statusCode?: number,
    originalError?: unknown
  ) {
    super(message)
    this.name = 'ApiError'
    this.statusCode = statusCode
    this.originalError = originalError
  }
}

/**
 * Handle and format errors
 */
export function handleError(error: unknown): string {
  if (error instanceof ApiError) {
    return error.message
  }
  
  if (error instanceof Error) {
    return error.message
  }
  
  return 'An unknown error occurred'
}
