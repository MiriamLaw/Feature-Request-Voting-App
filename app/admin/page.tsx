'use client';
import { useSession, signOut } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';
import { Feature, FeatureStatus } from '@/app/types/feature';

export default function AdminPage() {
  const { data: session } = useSession();
  const router = useRouter();
  const [features, setFeatures] = useState<Feature[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    // Redirect if not admin
    if (session && session.user?.role !== 'ADMIN') {
      router.push('/dashboard');
    }
  }, [session, router]);

  useEffect(() => {
    fetchFeatures();
  }, []);

  const fetchFeatures = async () => {
    try {
      const response = await fetch('/api/features');
      const data = await response.json();
      setFeatures(data);
    } catch (error) {
      console.error('Failed to fetch features:', error);
    }
  };

  const handleStatusChange = async (featureId: string, newStatus: FeatureStatus) => {
    try {
      const response = await fetch(`/api/features/${featureId}/status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status: newStatus }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to update status');
      }

      await fetchFeatures();
      setError(''); // Clear any existing error on success
    } catch (error) {
      console.error('Status update error:', error);
      setError(error instanceof Error ? error.message : 'Failed to update status');
    }
  };

  const handleLogout = async () => {
    await signOut({ redirect: true, callbackUrl: '/login' });
  };

  if (!session || session.user?.role !== 'ADMIN') {
    return <div>Access denied</div>;
  }

  return (
    <div className="min-h-screen bg-gray-100 py-6">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
          <div className="flex gap-4">
            <a
              href="/dashboard"
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
            >
              Back to Dashboard
            </a>
            <button
              onClick={handleLogout}
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700"
            >
              Logout
            </button>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Feature
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Votes
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Submitted
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {features.map((feature) => (
                <tr key={feature.id}>
                  <td className="px-6 py-4">
                    <div className="text-sm font-medium text-gray-900">{feature.title}</div>
                    <div className="text-sm text-gray-500">{feature.description}</div>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-500">
                    {feature.votes}
                  </td>
                  <td className="px-6 py-4">
                    <select
                      value={feature.status}
                      onChange={(e) => handleStatusChange(feature.id, e.target.value as FeatureStatus)}
                      className="block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                    >
                      <option value="PENDING">Pending</option>
                      <option value="PLANNED">Planned</option>
                      <option value="COMPLETED">Completed</option>
                    </select>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-500">
                    {new Date(feature.createdAt).toLocaleDateString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        
        {error && (
          <div className="mt-4 text-sm text-red-600">
            {error}
          </div>
        )}
      </div>
    </div>
  );
} 