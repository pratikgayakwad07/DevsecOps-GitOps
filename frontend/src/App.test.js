import { render, screen } from '@testing-library/react';
import App from './App';

beforeEach(() => {
  global.fetch = jest.fn().mockResolvedValue({
    json: async () => [],
  });
});

afterEach(() => {
  jest.restoreAllMocks();
});

test('renders the blog application header', () => {
  render(<App />);
  expect(screen.getByRole('heading', { name: /simple blog/i })).toBeInTheDocument();
});
