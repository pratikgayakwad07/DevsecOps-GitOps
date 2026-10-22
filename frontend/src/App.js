import React, { useState, useEffect } from 'react';
import './App.css';

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
    const response = await fetch('/api/posts');
    const data = await response.json();
    setPosts(data);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const url = editing ? `/api/posts/${editing}` : '/api/posts';
    
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
    await fetch(`/api/posts/${id}`, { method: 'DELETE' });
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
                <p className="post-meta">By {post.author} • {new Date(post.created_at).toLocaleDateString()}</p>
                <p className="post-excerpt">
                  {post.content.substring(0, 150)}
                  {post.content.length > 150 && '...'}
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
              By {selectedPost.author} • {new Date(selectedPost.created_at).toLocaleDateString()}
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
