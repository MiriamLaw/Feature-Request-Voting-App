import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth/next';
import { prisma } from '@/lib/prisma';

export async function POST(
  req: Request,
  { params }: { params: { featureId: string } }
) {
  try {
    const session = await getServerSession();
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const vote = await prisma.vote.create({
      data: {
        userId: session.user.id,
        featureId: params.featureId,
      },
    });

    return NextResponse.json(vote);
  } catch (error) {
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
    const session = await getServerSession();
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

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
    return NextResponse.json(
      { error: 'Failed to remove vote' },
      { status: 500 }
    );
  }
} 