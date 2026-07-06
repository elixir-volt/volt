import * as about from './about'
import * as home from './home'

export type PageMetadata = {
  slug: string
  title: string
  description: string
}

export const pages: PageMetadata[] = [
  { slug: 'home', title: home.title, description: home.description },
  { slug: 'about', title: about.title, description: about.description }
]

export function pageTitles() {
  return pages.map((page) => page.title)
}

export function findPage(slug: string) {
  return pages.find((page) => page.slug === slug)
}
