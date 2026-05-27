import { Routes, Route } from "react-router-dom";
import Nav from "./components/Nav";
import Footer from "./components/Footer";
import Home from "./pages/Home";
import Docs from "./pages/Docs";
import Install from "./pages/Install";
import Commands from "./pages/Commands";
import Onboarding from "./pages/Onboarding";

export default function App() {
  return (
    <>
      <div className="starfield" />
      <Nav />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/install" element={<Install />} />
        <Route path="/commands" element={<Commands />} />
        <Route path="/onboarding" element={<Onboarding />} />
        <Route path="/docs/*" element={<Docs />} />
        <Route path="*" element={<Home />} />
      </Routes>
      <Footer />
    </>
  );
}
