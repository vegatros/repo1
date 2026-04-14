import { NextResponse } from 'next/server'

// Proxy to AWS Lambda (app8) — keeps AWS URL server-side only
export async function GET() {
  const lambdaUrl = process.env.AWS_LAMBDA_URL

  if (!lambdaUrl) {
    return NextResponse.json({ error: 'AWS_LAMBDA_URL not configured' }, { status: 500 })
  }

  const res = await fetch(lambdaUrl, { cache: 'no-store' })
  const data = await res.json()
  return NextResponse.json(data)
}
