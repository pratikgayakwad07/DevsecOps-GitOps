import { render, screen } from '@testing-library/react';
import { createElement } from 'react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import App from './App';

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
    json: async () => [],
  }));
});

afterEach(() => {
  vi.unstubAllGlobals();
});

it('renders the blog application header', () => {
  render(createElement(App));
  expect(screen.getByRole('heading', { name: /simple blog/i })).toBeInTheDocument();
});
