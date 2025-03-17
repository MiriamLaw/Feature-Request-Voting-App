'use client';
import { useState, useEffect } from 'react';
import { useSession } from 'next-auth/react';
import { Feature, FeatureStatus } from '@/app/types/feature';

export default function FeatureCard({ feature, onVote }: { feature: Feature; onVote: () => void }) {
  const { data: session } = useSession();
  const [isVoting, setIsVoting] = useState(false);
  const [error, setError] = useState('');
  const [localHasVoted, setLocalHasVoted] = useState(feature.hasVoted);

  useEffect(() => {
    setLocalHasVoted(feature.hasVoted);
  }, [feature.hasVoted]);

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
      
      // Notify parent component to refresh the list if needed
      onVote();
    } catch (error) {
      console.error('Vote error:', error);
      setError(error instanceof Error ? error.message : 'Failed to vote');
      
      // Revert local state on error
      setLocalHasVoted(feature.hasVoted);
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
          className={`p-2 rounded-full transition-colors ${
            localHasVoted
              ? 'text-blue-600 bg-blue-50 hover:bg-blue-100'
              : 'text-gray-400 hover:text-blue-600 hover:bg-blue-50'
          } disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500`}
          title={!session 
            ? 'Please login to vote' 
            : localHasVoted 
              ? 'Click to remove your vote' 
              : 'Click to vote'
          }
          aria-label={localHasVoted ? "Remove vote" : "Vote for this feature"}
          tabIndex={0}
        >
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            viewBox="0 0 24 24" 
            className="w-6 h-6"
            fill={localHasVoted ? "currentColor" : "none"}
            stroke="currentColor" 
            strokeWidth={localHasVoted ? "0" : "2"}
          >
            <path 
              strokeLinecap="round" 
              strokeLinejoin="round" 
              d="M6.633 10.5c.806 0 1.533-.446 2.031-1.08a9.041 9.041 0 012.861-2.4c.723-.384 1.35-.956 1.653-1.715a4.498 4.498 0 00.322-1.672V3a.75.75 0 01.75-.75A2.25 2.25 0 0116.5 4.5c0 1.152-.26 2.243-.723 3.218-.266.558.107 1.282.725 1.282h3.126c1.026 0 1.945.694 2.054 1.715.045.422.068.85.068 1.285a11.95 11.95 0 01-2.649 7.521c-.388.482-.987.729-1.605.729H13.48c-.483 0-.964-.078-1.423-.23l-3.114-1.04a4.501 4.501 0 00-1.423-.23H5.904M14.25 9h2.25M5.904 18.75c.083.205.173.405.27.602.197.4-.078.898-.523.898h-.908c-.889 0-1.713-.518-1.972-1.368a12 12 0 01-.521-3.507c0-1.553.295-3.036.831-4.398C3.387 10.203 4.167 9.75 5 9.75h1.053c.472 0 .745.556.5.96a8.958 8.958 0 00-1.302 4.665c0 1.194.232 2.333.654 3.375z" 
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