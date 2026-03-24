import { Routes, Route, Link, NavLink } from "react-router-dom";
import { ConnectButton } from "@mysten/dapp-kit";
import BrowseRobots from "./pages/BrowseRobots.js";
import RobotDetail from "./pages/RobotDetail.js";
import ActiveRental from "./pages/ActiveRental.js";
import RentalHistory from "./pages/RentalHistory.js";

export default function App() {
  return (
    <div className="min-h-screen bg-gray-950 text-gray-100">
      <nav className="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
        <Link to="/" className="text-xl font-bold text-blue-400">
          Suibotics
        </Link>
        <div className="flex items-center gap-6">
          <NavLink
            to="/"
            end
            className={({ isActive }) =>
              isActive ? "text-blue-400" : "text-gray-400 hover:text-gray-100"
            }
          >
            Browse
          </NavLink>
          <NavLink
            to="/rental/active"
            className={({ isActive }) =>
              isActive ? "text-blue-400" : "text-gray-400 hover:text-gray-100"
            }
          >
            Active Rental
          </NavLink>
          <NavLink
            to="/history"
            className={({ isActive }) =>
              isActive ? "text-blue-400" : "text-gray-400 hover:text-gray-100"
            }
          >
            History
          </NavLink>
          <ConnectButton />
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-6 py-8">
        <Routes>
          <Route path="/" element={<BrowseRobots />} />
          <Route path="/robots/:id" element={<RobotDetail />} />
          <Route path="/rental/active" element={<ActiveRental />} />
          <Route path="/history" element={<RentalHistory />} />
        </Routes>
      </main>
    </div>
  );
}
