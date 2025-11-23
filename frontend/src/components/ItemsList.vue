<script setup lang="ts">
import { onMounted } from 'vue'
import { useItems } from '../composables/useItems'
import ItemCard from './ItemCard.vue'

// Use composable for items management
const { items, loading, error, fetchItems, refreshItems } = useItems()

// Fetch items on component mount
onMounted(() => {
  fetchItems()
})
</script>

<template>
  <div class="items-container">
    <h1 class="title">Items List</h1>
    
    <!-- Loading State -->
    <div v-if="loading" class="loading" role="status" aria-live="polite">
      <div class="spinner"></div>
      <p>Loading items...</p>
    </div>
    
    <!-- Error State -->
    <div v-else-if="error" class="error" role="alert">
      <p>{{ error }}</p>
      <button @click="refreshItems" class="retry-btn">Try Again</button>
    </div>
    
    <!-- Empty State -->
    <div v-else-if="items.length === 0" class="empty">
      <p>No items found</p>
    </div>
    
    <!-- Items Grid -->
    <div v-else class="items-grid">
      <ItemCard
        v-for="item in items"
        :key="item.id"
        :item="item"
      />
    </div>
    
    <!-- Refresh Button -->
    <button 
      v-if="!loading && items.length > 0"
      @click="refreshItems" 
      class="refresh-btn"
      :disabled="loading"
    >
      Refresh
    </button>
  </div>
</template>

<style scoped>
.items-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.title {
  text-align: center;
  color: white;
  margin-bottom: 2rem;
  font-size: 2rem;
  text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.2);
}

/* Loading State */
.loading {
  text-align: center;
  padding: 3rem 2rem;
  color: white;
}

.spinner {
  width: 50px;
  height: 50px;
  margin: 0 auto 1rem;
  border: 4px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Error State */
.error {
  text-align: center;
  padding: 2rem;
  background: rgba(255, 255, 255, 0.95);
  border-radius: 12px;
  color: #d32f2f;
}

.retry-btn {
  margin-top: 1rem;
  padding: 0.5rem 1.5rem;
  background: #d32f2f;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.95rem;
  transition: background 0.2s;
}

.retry-btn:hover {
  background: #b71c1c;
}

/* Empty State */
.empty {
  text-align: center;
  padding: 3rem 2rem;
  color: white;
}

/* Items Grid */
.items-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
}

/* Refresh Button */
.refresh-btn {
  display: block;
  margin: 0 auto;
  padding: 0.75rem 2rem;
  background: white;
  color: #667eea;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.refresh-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.refresh-btn:active:not(:disabled) {
  transform: scale(0.98);
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
