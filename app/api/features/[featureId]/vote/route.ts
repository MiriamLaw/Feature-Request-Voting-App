import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth/next';
import { prisma } from '@/lib/prisma';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';

export async function POST(
  req: Request,
  { params }: { params: { featureId: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const featureId = params.featureId;

    // Create the vote
    await prisma.vote.create({
      data: {
        userId: session.user.id,
        featureId: featureId,
      },
    });

    // Get updated feature data
    const updatedFeature = await prisma.feature.findUnique({
      where: { id: featureId },
      include: {
        votes: true,
        author: {
          select: { name: true }
        }
      }
    });

    if (!updatedFeature) {
      return NextResponse.json({ error: 'Feature not found' }, { status: 404 });
    }

    return NextResponse.json({
      id: updatedFeature.id,
      votes: updatedFeature.votes.length,
      hasVoted: true
    });
  } catch (error) {
    console.error('Vote error:', error);
    return NextResponse.json(
      { error: 'Failed to vote' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  req: Request,
  { params }: { params: { featureId: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // First check if the vote exists
    const existingVote = await prisma.vote.findUnique({
      where: {
        userId_featureId: {
          userId: session.user.id,
          featureId: params.featureId,
        },
      },
    });

    if (!existingVote) {
      return NextResponse.json(
        { error: 'Vote not found' },
        { status: 404 }
      );
    }

    // Delete the vote
    await prisma.vote.delete({
      where: {
        userId_featureId: {
          userId: session.user.id,
          featureId: params.featureId,
        },
      },
    });

    return NextResponse.json({ message: 'Vote removed' });
  } catch (error) {
    console.error('Remove vote error:', error);
    return NextResponse.json(
      { error: 'Failed to remove vote' },
      { status: 500 }
    );
  }
} 