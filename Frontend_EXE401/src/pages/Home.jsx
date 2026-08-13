import { useNavigate } from 'react-router-dom';
import { Scan, Clock, Monitor, Brush, Info } from 'lucide-react';
import './Home.css';

export default function Home() {
  const navigate = useNavigate();

  return (
    <div className="page-container" style={{ paddingTop: '80px' }}>
      <div className="header" style={{ position: 'absolute', top: 30, background: 'transparent' }}>
        <h1 className="header-title" style={{ fontSize: '32px' }}>Eink Clock</h1>
      </div>

      <div className="status-card">
        <div className="status-header">
          <div className="status-indicator">
            <span className="dot"></span>
            DEVICE OFFLINE
          </div>
          <button className="scan-btn" onClick={() => alert('Đang tìm kiếm...')}>
            <Scan size={16} /> Scan
          </button>
        </div>
        <h2 className="status-title">Chưa kết nối</h2>
        <p className="status-desc">Ấn Scan để tìm đồng hồ e-ink gần bạn</p>
      </div>

      <div className="menu-grid">
        <button className="menu-item bg-yellow" onClick={() => navigate('/settings')}>
          <div className="menu-icon"><Clock size={24} color="#1C1C1E" /></div>
          <span className="menu-text">Cài đặt chung</span>
          <span className="menu-arrow">›</span>
        </button>

        <button className="menu-item bg-blue" onClick={() => navigate('/interfaces')}>
          <div className="menu-icon"><Monitor size={24} color="#1C1C1E" /></div>
          <span className="menu-text">Các giao diện</span>
          <span className="menu-arrow">›</span>
        </button>

        <button className="menu-item bg-pink" onClick={() => navigate('/design')}>
          <div className="menu-icon"><Brush size={24} color="#1C1C1E" /></div>
          <span className="menu-text">Thiết kế</span>
          <span className="menu-arrow">›</span>
        </button>

        <button className="menu-item bg-purple" onClick={() => navigate('/info')}>
          <div className="menu-icon"><Info size={24} color="#1C1C1E" /></div>
          <span className="menu-text">Cập nhật firmware</span>
          <span className="menu-arrow">›</span>
        </button>
      </div>
    </div>
  );
}
