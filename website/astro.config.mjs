// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://dartlane.aioncw.com',
  integrations: [
    starlight({
      title: 'Dartlane',
      description: 'Release automation for Flutter and Dart, written in Dart.',
      logo: { src: './src/assets/logo.png' },
      favicon: '/favicon.png',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/AbhijithKonnayil/dartlane' },
      ],
      customCss: ['./src/styles/theme.css'],
      sidebar: [
        { label: 'Start here', items: ['docs/quick-start'] },
        {
          label: 'Guides',
          items: ['docs/writing-lanes-and-actions', 'docs/ci', 'docs/releasing'],
        },
      ],
    }),
  ],
});
