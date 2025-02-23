"use client"

import type { Feature, User, Vote } from "@prisma/client"
import { useSession } from "next-auth/react"
import { useRouter } from "next/navigation"
import { useState, useTransition } from "react"
import { Badge } from "./ui/badge"
import { Button } from "./ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "./ui/card"
import { ThumbsUp } from "lucide-react"

type FeatureWithAuthorAndVotes = Feature & {
  author: User
  votes: Vote[]
}

interface FeatureCardProps {
  feature: FeatureWithAuthorAndVotes
  voteCount: number
}

export function FeatureCard({ feature, voteCount }: FeatureCardProps) {
  const { data: session } = useSession()
  const router = useRouter()
  const [isPending, startTransition] = useTransition()
  const [optimisticVoteCount, setOptimisticVoteCount] = useState(voteCount)
  const [optimisticVoted, setOptimisticVoted] = useState(
    feature.votes.some((vote) => vote.userId === session?.user?.id),
  )

  const handleVote = async () => {
    if (!session) {
      router.push("/login")
      return
    }

    setOptimisticVoted(!optimisticVoted)
    setOptimisticVoteCount(optimisticVoted ? optimisticVoteCount - 1 : optimisticVoteCount + 1)

    startTransition(async () => {
      const response = await fetch("/api/vote", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          featureId: feature.id,
        }),
      })

      if (!response.ok) {
        // Revert optimistic update
        setOptimisticVoted(!optimisticVoted)
        setOptimisticVoteCount(optimisticVoted ? optimisticVoteCount + 1 : optimisticVoteCount - 1)
      }

      router.refresh()
    })
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between">
          <div>
            <CardTitle>{feature.title}</CardTitle>
            <div className="text-sm text-muted-foreground">
              by {feature.author.name || feature.author.email} · {new Date(feature.createdAt).toLocaleDateString()}
            </div>
          </div>
          {feature.status !== "PENDING" && (
            <Badge variant={feature.status === "COMPLETED" ? "default" : "secondary"}>
              {feature.status.toLowerCase()}
            </Badge>
          )}
        </div>
      </CardHeader>
      <CardContent>
        <p>{feature.description}</p>
      </CardContent>
      <CardFooter>
        <Button variant={optimisticVoted ? "default" : "outline"} size="sm" onClick={handleVote} disabled={isPending}>
          <ThumbsUp className="w-4 h-4 mr-2" />
          {optimisticVoteCount}
        </Button>
      </CardFooter>
    </Card>
  )
}

