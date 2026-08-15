// ============================================================================
//  Jota — identity and the owner bond
//
//  Two ids matter to this device:
//
//    * ITS OWN. Derived from the efuse MAC, so it is stable across reflashes
//      and unique per board without anything having to be provisioned. Shown
//      on the panel and broadcast in the advertisement, which is what lets a
//      person with two Jotas tell which one their phone is talking to.
//
//    * ITS OWNER'S. The uuid the phone generates once and presents on every
//      connection. Jota stores the first one that arrives with a correct pair
//      code, and from then on that phone reconnects silently — this is what
//      the contract means by "pair once; the bond is remembered".
//
//  A different phone is refused UNLESS it presents the code currently on the
//  e-paper, which transfers ownership. Possession of the device outranks the
//  stored bond on purpose: possession IS the security model here, and a device
//  that could lock out the person holding it would be worse, not better.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

// A phone's uuid, as text. Room for a canonical 36-character uuid.
static const size_t APP_ID_MAX = 40;

// This device's id, "7f3a91c4" — 8 hex characters plus a NUL.
const char *deviceId();

// The low 16 bits, for the two id bytes in the advertisement.
uint16_t deviceIdShort();

// The owner's app uuid, or "" if this Jota has never been paired.
const char *ownerAppId();
bool        hasOwner();

// True when [appId] is the phone this device belongs to.
bool isOwner(const char *appId);

// Take ownership. Persisted, so it survives a power cycle — a bond that
// forgot itself on reboot would send the user back to the pairing screen
// every morning.
void setOwner(const char *appId);

// Load the ids at boot. Generates and stores nothing the first time except
// what it derives from the MAC.
void identityBegin();

}  // namespace jota
