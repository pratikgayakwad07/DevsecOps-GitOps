import React, { useState, useEffect } from 'react';
import './App.css';

// Use relative path so it works behind the same origin / ingress, or set REACT_APP_API_URL at build time
const API_BASE = import.meta.env.VITE_API_URL || '';

function App() {
  const [posts, setPosts] = useState([]);
  const [currentView, setCurrentView] = useState('home');
  const [selectedPost, setSelectedPost] = useState(null);
  const [form, setForm] = useState({ title: '', content: '', author: '' });
  const [editing, setEditing] = useState(null);

  useEffect(() => {
    fetchPosts();
  }, []);

  const fetchPosts = async () => {
    try {
      const response = await fetch(`${API_BASE}/api/posts`);
      const data = await response.json();
      setPosts(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('Failed to fetch posts', err);
      setPosts([]);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const url = editing ? `${API_BASE}/api/posts/${editing}` : `${API_BASE}/api/posts`;
    
    await fetch(url, {
      method: editing ? 'PUT' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form)
    });
    
    setForm({ title: '', content: '', author: '' });
    setEditing(null);
    setCurrentView('home');
    fetchPosts();
  };

  const handleEdit = (post) => {
    setForm({ title: post.title, content: post.content, author: post.author });
    setEditing(post.id);
    setCurrentView('create');
  };

  const handleDelete = async (id) => {
    await fetch(`${API_BASE}/api/posts/${id}`, { method: 'DELETE' });
    fetchPosts();
  };

  const viewPost = (post) => {
    setSelectedPost(post);
    setCurrentView('view');
  };

  return (
    <div className="App">
      <header>
        <h1>📝 Simple Blog</h1>
        <nav>
          <button onClick={() => setCurrentView('home')} className={currentView === 'home' ? 'active' : ''}>
            Home
          </button>
          <button onClick={() => {
            setCurrentView('create');
            setEditing(null);
            setForm({ title: '', content: '', author: '' });
          }} className={currentView === 'create' ? 'active' : ''}>
            New Post
          </button>
        </nav>
      </header>

      {currentView === 'home' && (
        <div className="posts-list">
          <h2>Recent Posts</h2>
          {posts.length === 0 ? (
            <p className="no-posts">No posts yet. Create your first post!</p>
          ) : (
            posts.map(post => (
              <div key={post.id} className="post-card">
                <h3 onClick={() => viewPost(post)}>{post.title}</h3>
                <p className="post-meta">
                  By {post.author} • {post.created_at ? new Date(post.created_at).toLocaleDateString() : ''}
                </p>
                <div className="post-actions">
                  <button onClick={() => viewPost(post)}>Read More</button>
                  <button onClick={() => handleEdit(post)}>Edit</button>
                  <button onClick={() => handleDelete(post.id)} className="delete">Delete</button>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {currentView === 'create' && (
        <div className="create-post">
          <h2>{editing ? 'Edit Post' : 'Create New Post'}</h2>
          <form onSubmit={handleSubmit}>
            <input
              type="text"
              placeholder="Post Title"
              value={form.title}
              onChange={(e) => setForm({...form, title: e.target.value})}
              required
            />
            <input
              type="text"
              placeholder="Author Name"
              value={form.author}
              onChange={(e) => setForm({...form, author: e.target.value})}
              required
            />
            <textarea
              placeholder="Write your post content here..."
              value={form.content}
              onChange={(e) => setForm({...form, content: e.target.value})}
              required
            />
            <div className="form-actions">
              <button type="submit">{editing ? 'Update' : 'Publish'} Post</button>
              <button type="button" onClick={() => setCurrentView('home')}>Cancel</button>
            </div>
          </form>
        </div>
      )}

      {currentView === 'view' && selectedPost && (
        <div className="view-post">
          <button className="back-btn" onClick={() => setCurrentView('home')}>← Back to Posts</button>
          <article>
            <h1>{selectedPost.title}</h1>
            <p className="post-meta">
              By {selectedPost.author} • {selectedPost.created_at ? new Date(selectedPost.created_at).toLocaleDateString() : ''}
            </p>
            <div className="post-content">
              {selectedPost.content.split('\n').map((paragraph, index) => (
                <p key={index}>{paragraph}</p>
              ))}
            </div>
          </article>
          <div className="post-actions">
            <button onClick={() => handleEdit(selectedPost)}>Edit Post</button>
            <button onClick={() => handleDelete(selectedPost.id)} className="delete">Delete Post</button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
