<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface Item {
  id: number
  title: string
  body: string
  created_at: string
}

const items = ref<Item[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

// API URL - en dev local Vite proxy, en prod via variable d'environnement
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000'

async function fetchItems() {
  try {
    loading.value = true
    error.value = null
    const response = await fetch(`${API_URL}/items`)
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    items.value = await response.json()
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to fetch items'
    console.error('Error fetching items:', e)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchItems()
})
</script>

<template>
  <div class="items-container">
    <h1>📋 Items List</h1>
    
    <div v-if="loading" class="loading">
      Loading items...
    </div>
    
    <div v-else-if="error" class="error">
      ❌ Error: {{ error }}
    </div>
    
    <div v-else-if="items.length === 0" class="empty">
      No items found
    </div>
    
    <div v-else class="items-grid">
      <div v-for="item in items" :key="item.id" class="item-card">
        <h3>{{ item.title }}</h3>
        <p>{{ item.body }}</p>
        <small>Created: {{ new Date(item.created_at).toLocaleString() }}</small>
      </div>
    </div>
    
    <button @click="fetchItems" class="refresh-btn">🔄 Refresh</button>
  </div>
</template>

<style scoped>
.items-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

h1 {
  text-align: center;
  color: #42b983;
  margin-bottom: 2rem;
}

.loading, .error, .empty {
  text-align: center;
  padding: 2rem;
  font-size: 1.2rem;
}

.error {
  color: #ff4444;
}

.items-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.item-card {
  background: #f9f9f9;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 1.5rem;
  transition: transform 0.2s, box-shadow 0.2s;
}

.item-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.item-card h3 {
  margin: 0 0 0.5rem 0;
  color: #2c3e50;
}

.item-card p {
  margin: 0 0 1rem 0;
  color: #666;
  line-height: 1.5;
}

.item-card small {
  color: #999;
  font-size: 0.85rem;
}

.refresh-btn {
  display: block;
  margin: 0 auto;
  padding: 0.75rem 2rem;
  background: #42b983;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.2s;
}

.refresh-btn:hover {
  background: #359268;
}

.refresh-btn:active {
  transform: scale(0.98);
}
</style>
