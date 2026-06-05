import { useState, useEffect } from 'react'

export default function Eval() {
  const [runs, setRuns] = useState<any[]>([])
  const [attestations, setAttestations] = useState<any[]>([])

  useEffect(() => {
    fetch('/v1/eval/runs').then(r => r.json()).then(setRuns).catch(() => {})
    fetch('/v1/eval/attestations').then(r => r.json()).then(setAttestations).catch(() => {})
  }, [])

  return (
    <div>
      <h1 style={{ fontSize: '20px', marginBottom: '16px' }}>Eval</h1>

      <h3 style={{ fontSize: '13px', color: '#8b5cf6', marginBottom: '8px' }}>EVAL RUNS ({runs.length})</h3>
      {runs.map(r => (
        <div key={r.id} style={{ padding: '12px', background: '#1a1a1a', borderRadius: '6px', marginBottom: '8px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontSize: '13px' }}>{r.target_id}</span>
            <span style={{
              fontSize: '11px', padding: '2px 8px', borderRadius: '4px',
              background: r.status === 'PASSED' ? '#14532d' : '#7f1d1d',
              color: r.status === 'PASSED' ? '#4ade80' : '#fca5a5',
            }}>{r.status}</span>
          </div>
        </div>
      ))}

      <h3 style={{ fontSize: '13px', color: '#8b5cf6', marginBottom: '8px', marginTop: '24px' }}>
        ATTESTATIONS ({attestations.length})
      </h3>
      {attestations.map(a => (
        <div key={a.id} style={{ padding: '12px', background: '#1a1a1a', borderRadius: '6px', marginBottom: '8px' }}>
          <div style={{ fontSize: '13px' }}>Target: {a.target_id}</div>
          <div style={{ fontSize: '11px', color: '#666' }}>Canary: {a.canary_status}</div>
        </div>
      ))}
    </div>
  )
}
