import { render, screen } from '@testing-library/react';
import App from './App';

// Mock fetch so tests don't hit a real backend
beforeEach(() => {
  global.fetch = jest.fn(() =>
    Promise.resolve({
      json: () => Promise.resolve([]),
    })
  );
});

afterEach(() => {
  jest.resetAllMocks();
});

test('renders the blog header', () => {
  render(<App />);
  // The App renders an h1 with the blog title
  const heading = screen.getByRole('heading', { name: /simple blog/i });
  expect(heading).toBeInTheDocument();
});

test('renders the Home navigation button', () => {
  render(<App />);
  const homeBtn = screen.getByRole('button', { name: /home/i });
  expect(homeBtn).toBeInTheDocument();
});

test('renders the New Post navigation button', () => {
  render(<App />);
  const newPostBtn = screen.getByRole('button', { name: /new post/i });
  expect(newPostBtn).toBeInTheDocument();
});
