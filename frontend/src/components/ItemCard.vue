<script setup lang="ts">
import type { Item } from '../types/item'
import { formatDate } from '../utils/helpers'

interface Props {
  item: Item
}

defineProps<Props>()
</script>

<template>
  <article class="item-card">
    <h3 class="item-title">{{ item.title }}</h3>
    <p class="item-body">{{ item.body }}</p>
    <footer class="item-footer">
      <time :datetime="item.createdAt" class="item-date">
        {{ formatDate(item.createdAt) }}
      </time>
    </footer>
  </article>
</template>

<style scoped>
.item-card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  display: flex;
  flex-direction: column;
}

.item-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.item-title {
  margin: 0 0 0.75rem 0;
  color: #2c3e50;
  font-size: 1.25rem;
  font-weight: 600;
  line-height: 1.4;
}

.item-body {
  margin: 0 0 auto;
  color: #5a6c7d;
  line-height: 1.6;
  flex-grow: 1;
}

.item-footer {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid #e9ecef;
}

.item-date {
  color: #98a2b3;
  font-size: 0.875rem;
  font-style: italic;
}
</style>
