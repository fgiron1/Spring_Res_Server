package com.fgiron.votosResourceServer.Auth;

import lombok.Data;
import lombok.NonNull;
import lombok.RequiredArgsConstructor;

@Data
@RequiredArgsConstructor
public class LoginResult {
    
    @NonNull
    private String jwt;

}
