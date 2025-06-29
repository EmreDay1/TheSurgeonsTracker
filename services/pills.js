import { supabase } from '../config/supabase';

/**
 * Pills service for PillTracker app
 * Handles all medication CRUD operations with Supabase
 */

// Get all pills for current user
export const getUserPills = async () => {
  try {
    console.log('Fetching user pills...');
    
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const { data, error } = await supabase
      .from('pills')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching pills:', error.message);
      throw error;
    }

    console.log('Pills fetched successfully:', data?.length || 0);
    return data || [];
  } catch (error) {
    console.error('Get user pills failed:', error.message);
    throw error;
  }
};

// Add a new pill
export const addPill = async (pillData) => {
  try {
    console.log('Adding new pill:', pillData.name);
    
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const newPill = {
      user_id: user.id,
      name: pillData.name,
      time: pillData.time, // Format: "08:00" or "20:30"
      taken: false,
      created_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('pills')
      .insert([newPill])
      .select()
      .single();

    if (error) {
      console.error('Error adding pill:', error.message);
      throw error;
    }

    console.log('Pill added successfully:', data.name);
    return data;
  } catch (error) {
    console.error('Add pill failed:', error.message);
    throw error;
  }
};

// Update pill taken status
export const updatePillStatus = async (pillId, taken) => {
  try {
    console.log('Updating pill status:', pillId, taken);
    
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const updateData = {
      taken: taken,
      updated_at: new Date().toISOString()
    };

    // If marking as taken, record the time
    if (taken) {
      updateData.taken_at = new Date().toISOString();
    }

    const { data, error } = await supabase
      .from('pills')
      .update(updateData)
      .eq('id', pillId)
      .eq('user_id', user.id) // Ensure user can only update their own pills
      .select()
      .single();

    if (error) {
      console.error('Error updating pill status:', error.message);
      throw error;
    }

    console.log('Pill status updated successfully:', data.name);
    return data;
  } catch (error) {
    console.error('Update pill status failed:', error.message);
    throw error;
  }
};

// Delete a pill
export const deletePill = async (pillId) => {
  try {
    console.log('Deleting pill:', pillId);
    
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const { error } = await supabase
      .from('pills')
      .delete()
      .eq('id', pillId)
      .eq('user_id', user.id); // Ensure user can only delete their own pills

    if (error) {
      console.error('Error deleting pill:', error.message);
      throw error;
    }

    console.log('Pill deleted successfully');
    return true;
  } catch (error) {
    console.error('Delete pill failed:', error.message);
    throw error;
  }
};

// Reset all pills for today (mark all as not taken)
export const resetDailyPills = async () => {
  try {
    console.log('Resetting daily pills...');
    
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const { data, error } = await supabase
      .from('pills')
      .update({ 
        taken: false,
        taken_at: null,
        updated_at: new Date().toISOString()
      })
      .eq('user_id', user.id)
      .select();

    if (error) {
      console.error('Error resetting daily pills:', error.message);
      throw error;
    }

    console.log('Daily pills reset successfully:', data?.length || 0);
    return data || [];
  } catch (error) {
    console.error('Reset daily pills failed:', error.message);
    throw error;
  }
};

// Get today's pill schedule (sorted by time)
export const getTodaySchedule = async () => {
  try {
    console.log('Getting today\'s schedule...');
    
    const pills = await getUserPills();
    
    // Sort pills by time
    const sortedPills = pills.sort((a, b) => {
      const timeA = a.time || '00:00';
      const timeB = b.time || '00:00';
      return timeA.localeCompare(timeB);
    });

    console.log('Today\'s schedule loaded:', sortedPills.length);
    return sortedPills;
  } catch (error) {
    console.error('Get today schedule failed:', error.message);
    throw error;
  }
};

// Get adherence stats (how many pills taken vs total)
export const getAdherenceStats = async () => {
  try {
    console.log('Getting adherence stats...');
    
    const pills = await getUserPills();
    const totalPills = pills.length;
    const takenPills = pills.filter(pill => pill.taken).length;
    const adherenceRate = totalPills > 0 ? Math.round((takenPills / totalPills) * 100) : 0;

    const stats = {
      total: totalPills,
      taken: takenPills,
      missed: totalPills - takenPills,
      adherenceRate: adherenceRate
    };

    console.log('Adherence stats:', stats);
    return stats;
  } catch (error) {
    console.error('Get adherence stats failed:', error.message);
    throw error;
  }
};

export default {
  getUserPills,
  addPill,
  updatePillStatus,
  deletePill,
  resetDailyPills,
  getTodaySchedule,
  getAdherenceStats,
};
