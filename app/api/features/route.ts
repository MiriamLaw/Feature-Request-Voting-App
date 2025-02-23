import { getServerSession } from "next-auth/next"
import { NextResponse } from "next/server"
import { authOptions } from "../auth/[...nextauth]/route"
import { prisma } from "@/lib/prisma"

export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)

    if (!session) {
      return new NextResponse("Unauthorized", { status: 401 })
    }

    const json = await req.json()
    const { title, description } = json

    if (!title || !description) {
      return new NextResponse("Missing required fields", { status: 400 })
    }

    const feature = await prisma.feature.create({
      data: {
        title,
        description,
        authorId: session.user.id,
      },
    })

    return NextResponse.json(feature)
  } catch (error) {
    console.error(error)
    return new NextResponse("Internal Error", { status: 500 })
  }
}

