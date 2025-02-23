import { prisma } from "@/lib/prisma"
import { FeatureCard } from "./feature-card"

export async function FeatureList() {
  const features = await prisma.feature.findMany({
    include: {
      author: true,
      votes: true,
    },
    orderBy: {
      votes: {
        _count: "desc",
      },
    },
  })

  return (
    <div className="grid gap-4">
      {features.map((feature) => (
        <FeatureCard key={feature.id} feature={feature} voteCount={feature.votes.length} />
      ))}
    </div>
  )
}

