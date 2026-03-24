import { useRobots } from "../hooks/useRobots.js";
import RobotCard from "../components/RobotCard.js";

export default function BrowseRobots() {
  const { data: robots, isLoading, error } = useRobots();

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-100 mb-2">Available Robots</h1>
        <p className="text-gray-400">
          Browse and rent robots by the hour using TREAT tokens.
        </p>
      </div>

      {isLoading && (
        <div className="flex items-center justify-center py-24">
          <div className="animate-spin h-8 w-8 border-2 border-blue-500 border-t-transparent rounded-full" />
        </div>
      )}

      {error && (
        <div className="bg-red-900 border border-red-700 rounded-xl p-4 text-red-300">
          Failed to load robots: {error.message}
        </div>
      )}

      {robots && robots.length === 0 && (
        <div className="text-center py-24 text-gray-500">
          <p className="text-lg">No robots registered yet.</p>
          <p className="text-sm mt-2">Check back later or register your own robot.</p>
        </div>
      )}

      {robots && robots.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {robots.map((robot) => (
            <RobotCard key={robot.id} robot={robot} />
          ))}
        </div>
      )}
    </div>
  );
}
