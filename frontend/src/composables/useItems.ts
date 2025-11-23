import { ref, type Ref } from 'vue'
import type { Item } from '../types/item'
import { itemsService } from '../services/api.service'
import { transformApiItem } from '../utils/helpers'
import { handleError } from '../utils/errors'

/**
 * Composable return type
 */
export interface UseItemsReturn {
  items: Ref<Item[]>
  loading: Ref<boolean>
  error: Ref<string | null>
  fetchItems: () => Promise<void>
  refreshItems: () => Promise<void>
}

/**
 * Composable for managing items
 * Handles fetching, state management, and error handling
 */
export function useItems(): UseItemsReturn {
  const items = ref<Item[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  /**
   * Fetch items from API
   */
  async function fetchItems(): Promise<void> {
    try {
      loading.value = true
      error.value = null

      const apiItems = await itemsService.getAll()
      items.value = apiItems.map(transformApiItem)
    } catch (err) {
      error.value = handleError(err)
      console.error('[useItems] Error fetching items:', err)
    } finally {
      loading.value = false
    }
  }

  /**
   * Refresh items (alias for fetchItems for clarity)
   */
  async function refreshItems(): Promise<void> {
    await fetchItems()
  }

  return {
    items,
    loading,
    error,
    fetchItems,
    refreshItems
  }
}
