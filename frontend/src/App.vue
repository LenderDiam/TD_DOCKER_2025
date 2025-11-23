<script setup lang="ts">
import ItemsList from './components/ItemsList.vue'
import { config } from './config/app.config'
</script>

<template>
  <div class="app">
    <header class="app-header">
      <h1 class="app-title">TD Docker 2025</h1>
      <span v-if="config.env === 'development'" class="env-badge">
        Development Mode
      </span>
    </header>
    
    <main class="app-main">
      <ItemsList />
    </main>
    
    <footer class="app-footer">
      <p>&copy; 2025 TD Docker Project</p>
    </footer>
  </div>
</template>

<style scoped>
.app {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  flex-direction: column;
}

.app-header {
  text-align: center;
  color: white;
  padding: 2rem 1rem 1rem;
  position: relative;
}

.app-title {
  font-size: 2.5rem;
  margin: 0 0 0.5rem 0;
  text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.2);
  font-weight: 700;
}

.app-subtitle {
  font-size: 1.1rem;
  opacity: 0.9;
  margin: 0;
  font-weight: 300;
}

.env-badge {
  display: inline-block;
  margin-top: 0.5rem;
  padding: 0.25rem 0.75rem;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.app-main {
  flex: 1;
  padding: 1rem 0;
}

.app-footer {
  text-align: center;
  color: rgba(255, 255, 255, 0.7);
  padding: 1.5rem 1rem;
  font-size: 0.875rem;
}

.app-footer p {
  margin: 0;
}

/* Responsive */
@media (max-width: 768px) {
  .app-title {
    font-size: 1.75rem;
  }
  
  .app-subtitle {
    font-size: 0.95rem;
  }
}
</style>
