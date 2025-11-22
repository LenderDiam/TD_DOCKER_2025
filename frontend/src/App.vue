<script setup lang="ts">
import ItemsList from './components/ItemsList.vue'
</script>

<template>
  <div class="app">
    <header>
      <h1>🚀 TD Docker 2025</h1>
      <p>Vue 3 + TypeScript + Vite + Docker</p>
    </header>
    <ItemsList />
  </div>
</template>

<style scoped>
.app {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 2rem 0;
}

header {
  text-align: center;
  color: white;
  margin-bottom: 2rem;
}

header h1 {
  font-size: 2.5rem;
  margin: 0 0 0.5rem 0;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
}

header p {
  font-size: 1.1rem;
  opacity: 0.9;
  margin: 0;
}
</style>
