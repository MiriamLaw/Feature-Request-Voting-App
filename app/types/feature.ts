export type FeatureStatus = 'PENDING' | 'PLANNED' | 'COMPLETED';

export interface Feature {
  id: string;
  title: string;
  description: string;
  votes: number;
  hasVoted: boolean;
  status: FeatureStatus;
  createdAt: string;
  author: {
    name: string;
  };
}

export interface PrismaFeature {
  id: string;
  title: string;
  description: string;
  status: FeatureStatus;
  createdAt: Date;
  author: {
    name: string | null;
  };
  votes: {
    id: string;
  }[];
  _count?: {
    votes: number;
  };
}

export const mapPrismaFeatureToFeature = (
  prismaFeature: PrismaFeature,
  hasVoted: boolean
): Feature => ({
  id: prismaFeature.id,
  title: prismaFeature.title,
  description: prismaFeature.description,
  votes: prismaFeature._count?.votes ?? prismaFeature.votes.length,
  hasVoted,
  status: prismaFeature.status,
  createdAt: prismaFeature.createdAt.toISOString(),
  author: {
    name: prismaFeature.author.name ?? 'Anonymous'
  }
}); 