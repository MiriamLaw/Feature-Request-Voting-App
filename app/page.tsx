import { getServerSession } from "next-auth/next"
import { authOptions } from "./api/auth/[...nextauth]/route"
import { FeatureList } from "@/components/feature-list"
import { Button } from "@/components/ui/button"
import Link from "next/link"

export default async function Home() {
  const session = await getServerSession(authOptions)

  return (
    <main className="container max-w-5xl py-6">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Feature Requests</h1>
          <p className="text-muted-foreground">Vote on features you'd like to see implemented</p>
        </div>
        {session ? (
          <Button asChild>
            <Link href="/submit">Submit Feature Request</Link>
          </Button>
        ) : (
          <Button asChild>
            <Link href="/login">Sign in to Submit</Link>
          </Button>
        )}
      </div>
      <FeatureList />
    </main>
  )
}

