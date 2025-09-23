import React from 'react'
import Image from 'next/image'

export default function HandsPulsingLoader({ size = 120, minScale = 0.92, maxScale = 1.06, period = 900, enableGlow = true }) {
  const pulseMs = typeof period === 'number' ? period : 900
  const style = {
    '--min-scale': minScale,
    '--max-scale': maxScale,
    '--period': `${pulseMs}ms`
  }

  return (
    <div style={style} className="hands-pulse-root" aria-hidden>
      <style jsx>{`
        .hands-pulse-root { display: inline-flex; align-items: center; justify-content: center; }
        .hands-pulse-wrap { position: relative; width: ${size}px; height: ${size}px; }
        .hands-pulse-img { width: 100%; height: 100%; display: block; transform-origin: center; animation: hands-scale var(--period) ease-in-out infinite; }
        @keyframes hands-scale {
          0% { transform: scale(var(--min-scale)); }
          50% { transform: scale(var(--max-scale)); }
          100% { transform: scale(var(--min-scale)); }
        }
        .hands-pulse-glow { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: calc(${size}px * 1.4); height: calc(${size}px * 1.4); border-radius: 50%; pointer-events: none; opacity: 0.0; animation: hands-glow var(--period) ease-in-out infinite; }
        @keyframes hands-glow {
          0% { opacity: 0.0; }
          50% { opacity: 0.30; }
          100% { opacity: 0.0; }
        }
      `}</style>

      <div className="hands-pulse-wrap">
        {enableGlow && (
          <div className="hands-pulse-glow" style={{ background: 'radial-gradient(circle, rgba(255,165,0,0.25) 0%, rgba(255,165,0,0) 60%)' }} />
        )}
        <Image src="/images/hands_icon.png" alt="Loading" className="hands-pulse-img" width={size} height={size} />
      </div>
    </div>
  )
}
