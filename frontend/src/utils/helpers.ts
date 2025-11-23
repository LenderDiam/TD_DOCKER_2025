import type { ApiItem, Item } from '../types/item'

/**
 * Transform API item to frontend item
 * Note: API already uses camelCase, so this is a pass-through with validation
 */
export function transformApiItem(apiItem: ApiItem): Item {
  return {
    id: apiItem.id,
    title: apiItem.title,
    body: apiItem.body,
    createdAt: apiItem.createdAt
  }
}

/**
 * Format date to localized string
 * Returns a fallback message if date is invalid
 */
export function formatDate(date: string): string {
  if (!date) return 'Date not available'
  
  const parsedDate = new Date(date)
  
  if (isNaN(parsedDate.getTime())) {
    return 'Invalid date'
  }
  
  return parsedDate.toLocaleString('fr-FR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

/**
 * Delay utility for loading states (dev only)
 */
export function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}
