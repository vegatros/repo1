'use client'

import { useEffect, useState } from 'react'

export default function Home() {
  const [data, setData] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch('/api/data')
      .then(r => r.json())
      .then(d => setData(JSON.stringify(d, null, 2)))
      .catch(e => setData(`Error: ${e.message}`))
      .finally(() => setLoading(false))
  }, [])

  return (
    <main className="min-h-screen p-8 bg-gray-50">
      <h1 className="text-3xl font-bold mb-6">Vercel App1 — AWS Backend</h1>
      <section className="bg-white rounded-lg shadow p-6">
        <h2 className="text-xl font-semibold mb-4">Lambda Response</h2>
        {loading ? (
          <p className="text-gray-500">Loading...</p>
        ) : (
          <pre className="bg-gray-100 p-4 rounded text-sm overflow-auto">{data}</pre>
        )}
      </section>
    </main>
  )
}
