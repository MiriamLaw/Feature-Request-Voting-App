import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth/next';
import { prisma } from '@/lib/prisma';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';
import { FeatureStatus } from '@/app/types/feature';

export async function PATCH(
  req: Request,
  { params }: { params: { featureId: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.role || session.user.role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { status } = await req.json();
    
    // Validate status
    const validStatuses: FeatureStatus[] = ['PENDING', 'PLANNED', 'COMPLETED'];
    if (!validStatuses.includes(status)) {
      return NextResponse.json(
        { error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` },
        { status: 400 }
      );
    }

    const feature = await prisma.feature.update({
      where: {
        id: params.featureId,
      },
      data: {
        status: status as FeatureStatus,
      },
    });

    return NextResponse.json(feature);
  } catch (error) {
    console.error('Status update error:', error);
    return NextResponse.json(
      { error: 'Failed to update status' },
      { status: 500 }
    );
  }
} 