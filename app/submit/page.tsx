import { getServerSession } from "next-auth/next"
import { redirect } from "next/navigation"
import { authOptions } from "../api/auth/[...nextauth]/route"
import { FeatureForm } from "./feature-form"

export default async function SubmitPage() {
  const session = await getServerSession(authOptions)

  if (!session) {
    redirect("/login")
  }

  return (
    <main className="container max-w-2xl py-6">
      <div className="mb-8">
        <h1 className="text-3xl font-bold tracking-tight">Submit Feature Request</h1>
        <p className="text-muted-foreground">Share your ideas for new features</p>
      </div>
      <FeatureForm />
    </main>
  )
}

