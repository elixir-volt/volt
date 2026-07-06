import { describe, expect, test } from 'volt:test'
import { findPage, pages, pageTitles } from '../../assets/js/pages/metadata'

describe('example page metadata', () => {
  test('lists the pages rendered by the example navigation', () => {
    expect(pageTitles()).toEqual(['Home', 'About'])
    expect(pages.map((page) => page.slug)).toEqual(['home', 'about'])
  })

  test.each([
    ['home', 'Home', 'Welcome to the Volt example app'],
    ['about', 'About', 'Built with Volt — Elixir-native frontend tooling']
  ])('finds the %s page metadata', (slug, title, description) => {
    expect(findPage(String(slug))).toEqual({ slug, title, description })
  })

  test('returns undefined for unknown pages', () => {
    expect(findPage('missing')).toBeUndefined()
  })
})
