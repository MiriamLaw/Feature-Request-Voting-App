'use client';
import { useState, useEffect } from 'react';
import { useSession } from 'next-auth/react';
import { Feature, FeatureStatus } from '@/app/types/feature';

export default function FeatureCard({ feature, onVote }: { feature: Feature; onVote: () => void }) {
  const { data: session } = useSession();
  const [isVoting, setIsVoting] = useState(false);
  const [error, setError] = useState('');
  const [localHasVoted, setLocalHasVoted] = useState(feature.hasVoted);
  const [localVoteCount, setLocalVoteCount] = useState(feature.votes);

  useEffect(() => {
    setLocalHasVoted(feature.hasVoted);
    setLocalVoteCount(feature.votes);
  }, [feature.hasVoted, feature.votes]);

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

  const handleVote = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!session || isVoting) return;
    
    setIsVoting(true);
    setError('');
    
    try {
      const response = await fetch('/api/vote', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          featureId: feature.id,
        }),
      });
      
      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to vote');
      }

      const data = await response.json();
      
      // Update local state based on server response
      setLocalHasVoted(data.hasVoted);
      setLocalVoteCount(data.voteCount);
      
      // Notify parent component to refresh the list if needed
      onVote();
    } catch (error) {
      console.error('Vote error:', error);
      setError(error instanceof Error ? error.message : 'Failed to vote');
      
      // Revert local state on error
      setLocalHasVoted(feature.hasVoted);
      setLocalVoteCount(feature.votes);
    } finally {
      setIsVoting(false);
    }
  };

  const getStatusColor = (status: FeatureStatus) => {
    switch (status) {
      case 'PLANNED':
        return 'bg-blue-100 text-blue-800';
      case 'COMPLETED':
        return 'bg-green-100 text-green-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  // Default to PENDING if status is undefined
  const status = feature.status || 'PENDING';
  const formattedStatus = status.charAt(0) + status.toLowerCase().slice(1);

  return (
    <div className="bg-white rounded-lg shadow p-6 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h3 className="text-lg font-medium text-gray-900">{feature.title}</h3>
            {status !== 'PENDING' && (
              <span className={`px-2 py-1 text-xs rounded-full ${getStatusColor(status)}`}>
                {formattedStatus}
              </span>
            )}
          </div>
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
          className={`flex items-center space-x-2 px-4 py-2 rounded-md ${
            localHasVoted
              ? 'bg-red-100 text-red-700 hover:bg-red-200'
              : 'bg-green-600 text-white hover:bg-green-700'
          } disabled:opacity-50 transition-colors`}
          title={!session 
            ? 'Please login to vote' 
            : localHasVoted 
              ? 'Click to remove vote' 
              : 'Click to vote'
          }
        >
          <span>{localVoteCount}</span>
          {localHasVoted ? (
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
                d="M20 12H4"
              />
            </svg>
          ) : (
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
                d="M12 6v12m6-6H6"
              />
            </svg>
          )}
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