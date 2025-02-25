'use client';
import { useState } from 'react';
import { useSession } from 'next-auth/react';

type Feature = {
  id: string;
  title: string;
  description: string;
  votes: number;
  hasVoted: boolean;
  createdAt: string;
  author: {
    name: string;
  };
};

export default function FeatureCard({ feature, onVote }: { feature: Feature; onVote: () => void }) {
  const { data: session } = useSession();
  const [isVoting, setIsVoting] = useState(false);
  const [error, setError] = useState('');

  const formatDateTime = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const handleVote = async () => {
    if (!session) return;
    setIsVoting(true);
    setError('');
    
    try {
      console.log('Voting for feature:', feature.id, feature.hasVoted ? 'remove vote' : 'add vote');
      
      const response = await fetch(`/api/features/${feature.id}/vote`, {
        method: feature.hasVoted ? 'DELETE' : 'POST',
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Failed to vote');
      }
      
      await onVote();
    } catch (error) {
      console.error('Vote error:', error);
      setError(error.message);
    } finally {
      setIsVoting(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow p-6 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3 className="text-lg font-medium text-gray-900">{feature.title}</h3>
          <p className="mt-1 text-sm text-gray-500">{feature.description}</p>
          <div className="mt-2 flex items-center text-sm text-gray-500">
            <span>Submitted by {feature.author.name}</span>
            <span className="mx-2">•</span>
            <span>{formatDateTime(feature.createdAt)}</span>
          </div>
        </div>
        <button
          onClick={handleVote}
          disabled={isVoting || !session}
          className={`flex items-center space-x-1 px-4 py-2 rounded-md ${
            feature.hasVoted
              ? 'bg-indigo-100 text-indigo-700'
              : 'bg-indigo-600 text-white hover:bg-indigo-700'
          } disabled:opacity-50`}
          title={!session ? 'Please login to vote' : ''}
          data-feature-id={feature.id}
        >
          <span>{feature.votes}</span>
          <svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M5 15l7-7 7 7"
            />
          </svg>
        </button>
      </div>
      {error && (
        <div className="mt-2 text-sm text-red-600">
          {error}
        </div>
      )}
    </div>
  );
} 