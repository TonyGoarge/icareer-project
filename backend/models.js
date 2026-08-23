const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true
  },
  password: {
    type: String,
    required: true
  }
}, { timestamps: true });

const RideSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  pickup: {
    type: String,
    required: true
  },
  destination: {
    type: String,
    required: true
  },
  estimatedPrice: {
    type: Number,
    required: true
  },
  status: {
    type: String,
    enum: ['Searching', 'Driver Found', 'Completed', 'Cancelled'],
    default: 'Searching'
  },
  driverName: {
    type: String,
    default: ''
  },
  driverVehicle: {
    type: String,
    default: ''
  }
}, { timestamps: true });

const User = mongoose.model('User', UserSchema);
const Ride = mongoose.model('Ride', RideSchema);

module.exports = { User, Ride };
