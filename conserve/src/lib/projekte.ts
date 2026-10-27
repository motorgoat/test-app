import { getCollection, type CollectionEntry } from 'astro:content';

type Projekt = CollectionEntry<'projekte'>;

// Neueste zuerst; Projekte ohne Jahr ans Ende, danach nach `order` und Titel.
const byNewest = (a: Projekt, b: Projekt) =>
  (b.data.jahr ?? 0) - (a.data.jahr ?? 0) ||
  a.data.order - b.data.order ||
  a.data.title.localeCompare(b.data.title, 'de');

export async function getProjekte() {
  return (await getCollection('projekte')).sort(byNewest);
}

export async function getFeaturedProjekte(limit = 6) {
  return (await getProjekte()).filter((p) => p.data.featured).slice(0, limit);
}
