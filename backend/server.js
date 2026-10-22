const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'blog_db'
});

// GET all posts
app.get('/api/posts', (req, res) => {
  db.query('SELECT * FROM posts ORDER BY created_at DESC', (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// GET single post
app.get('/api/posts/:id', (req, res) => {
  db.query('SELECT * FROM posts WHERE id = ?', [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: 'Post not found' });
    res.json(results[0]);
  });
});

// POST new post
app.post('/api/posts', (req, res) => {
  const { title, content, author } = req.body;
  db.query('INSERT INTO posts (title, content, author) VALUES (?, ?, ?)', 
    [title, content, author], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ id: result.insertId, title, content, author });
  });
});

// PUT update post
app.put('/api/posts/:id', (req, res) => {
  const { title, content, author } = req.body;
  db.query('UPDATE posts SET title = ?, content = ?, author = ? WHERE id = ?',
    [title, content, author, req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Post updated' });
  });
});

// DELETE post
app.delete('/api/posts/:id', (req, res) => {
  db.query('DELETE FROM posts WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Post deleted' });
  });
});

const port = process.env.PORT || 5003;
app.listen(port, () => console.log(`Server running on port ${port}`));