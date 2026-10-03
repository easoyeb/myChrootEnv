import { defineConfig } from 'vitepress'
import { readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const docsDir = fileURLToPath(new URL('../docs', import.meta.url))

const excluded = ['AI Chat Workflow.md']

const docItems = readdirSync(docsDir)
  .filter((f) => f.endsWith('.md') && excluded.indexOf(f) === -1)
  .sort((a, b) => a.localeCompare(b))
  .map((f) => {
    const name = f.replace(/\.md$/, '')
    return { text: name.replace(/_/g, ' '), link: encodeURI(`/docs/${name}`) }
  })

export default defineConfig({
  title: 'myChrootEnv',
  description: 'Android development and AI-assisted coding in proot/chroot on ARM64',
  base: '/myChrootEnv/',
  srcDir: '.',
  srcExclude: excluded.map((f) => `docs/${f}`),
  rewrites: { 'README.md': 'index.md' },
  cleanUrls: true,
  lastUpdated: true,
  themeConfig: {
    nav: [{ text: 'Home', link: '/' }],
    sidebar: [{ text: 'Docs', items: docItems }],
    socialLinks: [{ icon: 'github', link: 'https://github.com/easoyeb/myChrootEnv' }],
    search: { provider: 'local' },
    editLink: {
      pattern: 'https://github.com/easoyeb/myChrootEnv/edit/main/:path'
    }
  }
})
