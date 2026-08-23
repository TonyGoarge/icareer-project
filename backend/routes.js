const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { User, Ride } = require('./models');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_12345';

// Authentication Middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Access token missing' });

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid or expired token' });
    req.user = user;
    next();
  });
};

// --- AUTH ROUTER ---

// Register
router.post('/auth/register', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ email, password: hashedPassword });
    await user.save();

    const token = jwt.sign({ userId: user._id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ token, user: { id: user._id, email: user.email } });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Login
router.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign({ userId: user._id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
    res.status(200).json({ token, user: { id: user._id, email: user.email } });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Logout (mock clear session / log info)
router.post('/auth/logout', (req, res) => {
  res.status(200).json({ message: 'Logged out successfully' });
});

// --- RIDES ROUTER ---

// Helper function to update status based on simulation timeline
const getSimulatedRideStatus = async (ride) => {
  if (ride.status === 'Cancelled' || ride.status === 'Completed') {
    return ride;
  }

  const elapsedMs = Date.now() - new Date(ride.createdAt).getTime();
  let updated = false;

  if (elapsedMs >= 30000 && ride.status !== 'Completed') {
    ride.status = 'Completed';
    updated = true;
  } else if (elapsedMs >= 10000 && ride.status === 'Searching') {
    ride.status = 'Driver Found';
    ride.driverName = 'David Miller';
    ride.driverVehicle = 'Tesla Model 3, White (LN88 SXX)';
    updated = true;
  }

  if (updated) {
    await ride.save();
  }
  return ride;
};

// Request Ride
router.post('/rides/request', authenticateToken, async (req, res) => {
  try {
    const { pickup, destination } = req.body;
    if (!pickup || !destination) {
      return res.status(400).json({ error: 'Pickup and destination are required' });
    }

    // Cancel any other currently active rides to prevent duplicates
    await Ride.updateMany(
      { userId: req.user.userId, status: { $in: ['Searching', 'Driver Found'] } },
      { status: 'Cancelled' }
    );

    // Calculate a simple simulated price ($15 to $45)
    const basePrice = 15;
    const randPrice = Math.floor(Math.random() * 30);
    const estimatedPrice = basePrice + randPrice;

    const ride = new Ride({
      userId: req.user.userId,
      pickup,
      destination,
      estimatedPrice,
      status: 'Searching'
    });

    await ride.save();
    res.status(201).json(ride);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get Active Ride
router.get('/rides/active', authenticateToken, async (req, res) => {
  try {
    let ride = await Ride.findOne({
      userId: req.user.userId,
      status: { $in: ['Searching', 'Driver Found'] }
    }).sort({ createdAt: -1 });

    if (ride) {
      ride = await getSimulatedRideStatus(ride);
      // If simulated status transitioned to Completed, it won't be active anymore. But return it so user knows.
    } else {
      // Find the last completed or cancelled ride just for UI convenience
      ride = await Ride.findOne({ userId: req.user.userId }).sort({ createdAt: -1 });
    }

    res.status(200).json(ride);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Cancel Ride
router.post('/rides/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const ride = await Ride.findOne({ _id: req.params.id, userId: req.user.userId });
    if (!ride) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    if (ride.status === 'Completed') {
      return res.status(400).json({ error: 'Cannot cancel a completed ride' });
    }

    ride.status = 'Cancelled';
    await ride.save();
    res.status(200).json(ride);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get Status
router.get('/rides/:id/status', authenticateToken, async (req, res) => {
  try {
    let ride = await Ride.findOne({ _id: req.params.id, userId: req.user.userId });
    if (!ride) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    ride = await getSimulatedRideStatus(ride);
    res.status(200).json(ride);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
